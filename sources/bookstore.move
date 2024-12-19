/// Module: bookstore
module bookstore::bookstore;

    use std::string::String;
    use sui::balance::{Balance, zero};
    use sui::coin::{Coin, split, put, take};
    use sui::table::{Self, Table};
    use sui::event;
    use sui::sui::SUI;

    //define errors
    const ONLYOWNERISALLOWED: u64 = 0;
    const INSUFFICIENTBALANCE: u64 = 2;
    const INVALIDRATING: u64 = 3;

    //define data types

    public struct Bookstore has key, store {
        id: UID,
        store_id: ID,
        name: String,
        books: Table<ID, Book>,
        balance: Balance<SUI>,
        ratings: Table<ID, Table<address, Rating>>,
        inquiries: Table<address, Inquiry>,
    }
    public struct Rating has store, key {
        id: UID,
        rating: u64,
        by: address,
    }

    public struct Inquiry has key, store {
        id: UID,
        by: address,
        message: String,
    }

    public struct Book has key, store {
        id: UID,
        title: String,
        description: String,
        price: u64,
    }

    //admin capabilities
    public struct OwnerCap has key {
        id: UID,
        store_id: ID,
    }

    //define events

    public struct RatingAdded has copy, drop {
        by: address,
        rating: u64,
    }

    public struct InquirySubmitted has copy, drop {
        by: address,
        message: String,
    }

    public struct BookstoreAdded has copy, drop {
        id: ID,
        name: String,
    }

    public struct BookAdded has copy, drop {
        title: String,
        description: String,
    }

    public struct WithdrawAmount has copy, drop {
        amount: u64,
        recipient: address,
    }

    //integrate bookstore into your app
    public entry fun integrate_bookstore(name: String, ctx: &mut TxContext) {
        //generate unique ids
        let id = object::new(ctx);
        //generate store id
        let store_id = object::uid_to_inner(&id);

        //register your bookstore

        let new_store = Bookstore {
            id,
            store_id,
            name,
            books: table::new(ctx),
            balance: zero<SUI>(),
            ratings: table::new(ctx),
            inquiries: table::new(ctx),
        };

        //transfer the capabilities to the owner of the bookstore

        transfer::transfer(
            OwnerCap {
                id: object::new(ctx),
                store_id,
            },
            tx_context::sender(ctx),
        );

        //emit event

        event::emit(BookstoreAdded {
            id: store_id,
            name,
        });
        //share your bookstore
        transfer::share_object(new_store);
    }

    //add books to the bookstore
    public entry fun add_books(
        store: &mut Bookstore,
        owner: &OwnerCap,
        title: String,
        description: String,
        price: u64,
        ctx: &mut TxContext,
    ) {
        //verify to make sure only the owner can perform the action
        assert!(&owner.store_id == object::uid_as_inner(&store.id), ONLYOWNERISALLOWED);
        //create a new book
        let new_book = Book {
            id: object::new(ctx),
            title,
            description,
            price,
        };
        let id_ = object::id(&new_book);
        //add new book to bookstore
        store.books.add(id_, new_book);

        //emit event
        event::emit(BookAdded {
            title,
            description,
        });
    }

    //users buy books and get a receipt
    public entry fun purchase_book(
        store: &mut Bookstore,
        book_id: ID,
        payment: &mut Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        //verify the user has sufficient balance to perform the transaction
        assert!(store.books[book_id].price >= payment.value(), INSUFFICIENTBALANCE);

        let book_price = store.books[book_id].price;

        let pay = payment.split(book_price, ctx);

        put(&mut store.balance, pay);
    }

    //rate bookstore
    public entry fun rate_bookstore(store: &mut Bookstore, book_id: ID, rating: u64, ctx: &mut TxContext) {
        //ensure rating is valid
        assert!(rating > 0 && rating < 6, INVALIDRATING);
        //create rating
        let new_rating = Rating {
            id: object::new(ctx),
            rating,
            by: tx_context::sender(ctx),
        };
        //check if no ratings exist for the book
        let table1 = &mut store.ratings;
        if (!table::contains(table1, book_id)) {
            let new_table = table::new<address, Rating>(ctx);
            table::add(table1, book_id, new_table);
        };
        //borrow child table
        let child_table = table::borrow_mut(&mut store.ratings, book_id);
        //add rating object to child table
        child_table.add(ctx.sender(), new_rating);

        //emit event
        event::emit(RatingAdded {
            by: tx_context::sender(ctx),
            rating,
        });
    }

    //inquire about a book
    public entry fun inquire_bookstore(store: &mut Bookstore, message: String, ctx: &mut TxContext) {
        //create a new inquiry
        let new_inquiry = Inquiry {
            id: object::new(ctx),
            by: tx_context::sender(ctx),
            message,
        };
        //add inquiry to inquiries
        store.inquiries.add(ctx.sender(), new_inquiry);
        //emit event
        event::emit(InquirySubmitted {
            by: tx_context::sender(ctx),
            message,
        });
    }

    //withdraw funds from bookstore

    public entry fun withdraw_all_funds(
        owner: &OwnerCap,
        store: &mut Bookstore,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        //ensure only the owner can perform the action
        assert!(&owner.store_id == object::uid_as_inner(&store.id), ONLYOWNERISALLOWED);

        let total_balance = store.balance.value();

        let withdraw_all = take(&mut store.balance, total_balance, ctx);
        transfer::public_transfer(withdraw_all, recipient);

        //emit event
        event::emit(WithdrawAmount {
            amount: total_balance,
            recipient,
        });
    }

    //owner withdraw specific funds
    public entry fun withdraw_specific_funds(
        owner: &OwnerCap,
        store: &mut Bookstore,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext,
    ) {
        //verify amount is sufficient
        assert!(amount > 0 && amount <= store.balance.value(), INSUFFICIENTBALANCE);

        //ensure only the owner can perform the action

        assert!(&owner.store_id == object::uid_as_inner(&store.id), ONLYOWNERISALLOWED);

        let withdraw_amount = take(&mut store.balance, amount, ctx);
        transfer::public_transfer(withdraw_amount, recipient);

        //emit event

        event::emit(WithdrawAmount {
            amount,
            recipient,
        });
    }