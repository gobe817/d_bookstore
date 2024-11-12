#[allow(duplicate_alias)]
module bookstore::store_management {
    use sui::transfer;
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use std::option::{Option, none, some, is_some, contains, borrow};

    // Error codes
    const EInvalidTransaction: u64 = 1;
    const EInvalidBook: u64 = 2;
    const EDispute: u64 = 3;
    const EAlreadyResolved: u64 = 4;
    const ENotStore: u64 = 5;
    const EInvalidRefundRequest: u64 = 6;
    const EDeadlinePassed: u64 = 7;
    const EInsufficientEscrow: u64 = 8;

    // Structs

    public struct Transaction has key, store {
        id: UID,
        customer: address,
        book: vector<u8>,
        quantity: u64,
        price: u64,
        escrow: Balance<SUI>,
        dispute: bool,
        rating: Option<u64>,
        status: vector<u8>,
        store: Option<address>,
        transactionFulfilled: bool,
        created_at: u64,
        deadline: u64,
    }

    public struct BookReview has key, store {
        id: UID,
        customer: address,
        review: vector<u8>,
    }

    // Accessors

    public entry fun get_book(transaction: &Transaction): vector<u8> {
        transaction.book
    }

    public entry fun get_transaction_price(transaction: &Transaction): u64 {
        transaction.price
    }

    public entry fun get_transaction_status(transaction: &Transaction): vector<u8> {
        transaction.status
    }

    public entry fun get_transaction_deadline(transaction: &Transaction): u64 {
        transaction.deadline
    }

    // Entry functions

    public entry fun create_transaction(
        book: vector<u8>, quantity: u64, price: u64, clock: &Clock, duration: u64,
        open: vector<u8>, ctx: &mut TxContext
    ) {
        let transaction_id = object::new(ctx);
        let deadline = clock::timestamp_ms(clock) + duration;
        transfer::share_object(Transaction {
            id: transaction_id,
            customer: tx_context::sender(ctx),
            store: none(),
            book,
            quantity,
            rating: none(),
            status: open,
            price,
            escrow: balance::zero(),
            transactionFulfilled: false,
            dispute: false,
            created_at: clock::timestamp_ms(clock),
            deadline,
        });
    }

    public entry fun accept_transaction(transaction: &mut Transaction, ctx: &mut TxContext) {
        assert!(!is_some(&transaction.store), EInvalidTransaction);
        transaction.store = some(tx_context::sender(ctx));
    }

    public entry fun fulfill_transaction(transaction: &mut Transaction, clock: &Clock, ctx: &mut TxContext) {
        assert!(contains(&transaction.store, &tx_context::sender(ctx)), EInvalidBook);
        assert!(clock::timestamp_ms(clock) < transaction.deadline, EDeadlinePassed);
        transaction.transactionFulfilled = true;
    }

    public entry fun mark_transaction_complete(transaction: &mut Transaction, ctx: &mut TxContext) {
        assert!(contains(&transaction.store, &tx_context::sender(ctx)), ENotStore);
        transaction.transactionFulfilled = true;
    }

    public entry fun dispute_transaction(transaction: &mut Transaction, ctx: &mut TxContext) {
        assert!(transaction.customer == tx_context::sender(ctx), EDispute);
        transaction.dispute = true;
    }

    public entry fun resolve_dispute(
        transaction: &mut Transaction, resolved: bool, ctx: &mut TxContext
    ) {
        assert!(transaction.customer == tx_context::sender(ctx), EDispute);
        assert!(transaction.dispute, EAlreadyResolved);
        assert!(is_some(&transaction.store), EInvalidTransaction);
        let escrow_amount = balance::value(&transaction.escrow);
        let escrow_coin = coin::take(&mut transaction.escrow, escrow_amount, ctx);
        if (resolved) {
            let store = *borrow(&transaction.store);
            transfer::public_transfer(escrow_coin, store);
        } else {
            transfer::public_transfer(escrow_coin, transaction.customer);
        };

        transaction.store = none();
        transaction.transactionFulfilled = false;
        transaction.dispute = false;
    }

    public entry fun release_payment(
        transaction: &mut Transaction, clock: &Clock, review: vector<u8>, ctx: &mut TxContext
    ) {
        assert!(transaction.customer == tx_context::sender(ctx), ENotStore);
        assert!(transaction.transactionFulfilled && !transaction.dispute, EInvalidBook);
        assert!(clock::timestamp_ms(clock) > transaction.deadline, EDeadlinePassed);
        assert!(is_some(&transaction.store), EInvalidTransaction);
        let store = *borrow(&transaction.store);
        let escrow_amount = balance::value(&transaction.escrow);
        assert!(escrow_amount > 0, EInsufficientEscrow);
        let escrow_coin = coin::take(&mut transaction.escrow, escrow_amount, ctx);
        transfer::public_transfer(escrow_coin, store);

        let bookReview = BookReview {
            id: object::new(ctx),
            customer: tx_context::sender(ctx),
            review,
        };

        transfer::public_transfer(bookReview, tx_context::sender(ctx));

        transaction.store = none();
        transaction.transactionFulfilled = false;
        transaction.dispute = false;
    }

    public entry fun add_funds(transaction: &mut Transaction, amount: Coin<SUI>, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == transaction.customer, ENotStore);
        let added_balance = coin::into_balance(amount);
        balance::join(&mut transaction.escrow, added_balance);
    }

    public entry fun cancel_transaction(transaction: &mut Transaction, ctx: &mut TxContext) {
        assert!(
            transaction.customer == tx_context::sender(ctx) || contains(&transaction.store, &tx_context::sender(ctx)),
            ENotStore
        );

        if (is_some(&transaction.store) && !transaction.transactionFulfilled && !transaction.dispute) {
            let escrow_amount = balance::value(&transaction.escrow);
            let escrow_coin = coin::take(&mut transaction.escrow, escrow_amount, ctx);
            transfer::public_transfer(escrow_coin, transaction.customer);
        };

        transaction.store = none();
        transaction.transactionFulfilled = false;
        transaction.dispute = false;
    }

    public entry fun rate_store(transaction: &mut Transaction, rating: u64, ctx: &mut TxContext) {
        assert!(transaction.customer == tx_context::sender(ctx), ENotStore);
        transaction.rating = some(rating);
    }

    public entry fun update_book(transaction: &mut Transaction, new_book: vector<u8>, ctx: &mut TxContext) {
        assert!(transaction.customer == tx_context::sender(ctx), ENotStore);
        transaction.book = new_book;
    }

    public entry fun update_transaction_price(transaction: &mut Transaction, new_price: u64, ctx: &mut TxContext) {
        assert!(transaction.customer == tx_context::sender(ctx), ENotStore);
        transaction.price = new_price;
    }

    public entry fun update_transaction_quantity(transaction: &mut Transaction, new_quantity: u64, ctx: &mut TxContext) {
        assert!(transaction.customer == tx_context::sender(ctx), ENotStore);
        transaction.quantity = new_quantity;
    }

    public entry fun update_transaction_deadline(transaction: &mut Transaction, new_deadline: u64, ctx: &mut TxContext) {
        assert!(transaction.customer == tx_context::sender(ctx), ENotStore);
        transaction.deadline = new_deadline;
    }

    public entry fun update_transaction_status(transaction: &mut Transaction, completed: vector<u8>, ctx: &mut TxContext) {
        assert!(transaction.customer == tx_context::sender(ctx), ENotStore);
        transaction.status = completed;
    }

    public entry fun request_refund(transaction: &mut Transaction, ctx: &mut TxContext) {
        assert!(tx_context::sender(ctx) == transaction.customer, ENotStore);
        assert!(!transaction.transactionFulfilled && !transaction.dispute, EInvalidRefundRequest);
        let escrow_amount = balance::value(&transaction.escrow);
        let escrow_coin = coin::take(&mut transaction.escrow, escrow_amount, ctx);
        transfer::public_transfer(escrow_coin, transaction.customer);

        transaction.store = none();
        transaction.transactionFulfilled = false;
        transaction.dispute = false;
    }
}
