module bookstore::bookstore {
    use sui::balance::{Balance, Self};
    use sui::coin::{Coin, Self};
    use std::string::{String};
    use sui::event;
    use sui::sui::SUI;


    //errors
    const ENotOwner: u64 = 0;
    const EBookNotAvailable: u64 = 2;
    const ErrorInsufficientAmount: u64 = 3;

    //define data types
    public struct Bookstore has key, store {
        id: UID,
        name: String,
        books: vector<Book>,
        book_count: u64,
        balance: Balance<SUI>
    }

    public struct Book has key, store {
        id: UID,
        book_id: u64,
        title: String,
        description: String,
        price: u64,
        sold: bool,
        owner: address
    }

    public struct AdminCap has key {
        id: UID,
        bookstore_id: ID
    }

    //events
    public struct BookstoreCreated has drop, copy {
        name_of_bookstore: String
    }

    public struct AmountWithdrawn has drop, copy {
        recipient: address,
        amount: u64
    }

    //functions

    //function to create bookstore
    public entry fun create_bookstore(name: String, ctx: &mut TxContext): String {
        let id = object::new(ctx);
        let book_count: u64 = 0;
        let balance = balance::zero<SUI>();
        let bookstore_id = object::uid_to_inner(&id);
        let new_bookstore = Bookstore { 
            id, 
            book_count,
            name,
            books: vector::empty(),
            balance
        };

        transfer::transfer(AdminCap {
            id: object::new(ctx),
            bookstore_id,
        }, tx_context::sender(ctx));

        transfer::share_object(new_bookstore);
        event::emit(BookstoreCreated {
            name_of_bookstore: name
        });

        name
    }

    //function to add books to the bookstore
    public entry fun add_book(
        owner: &AdminCap,
        bookstore: &mut Bookstore,
        title: String,
        price: u64,
        description: String,
        ctx: &mut TxContext
    ) {
        //verify that only the owner of the bookstore can add books
        assert!(&owner.bookstore_id == object::uid_to_inner(&bookstore.id), ENotOwner);
        let book_id = bookstore.books.length();
        
        let new_book = Book {
            id: object::new(ctx),
            book_id,
            title,
            description,
            price,
            sold: false,
            owner: tx_context::sender(ctx),
        };

        bookstore.books.push_back(new_book);
        bookstore.book_count = bookstore.book_count + 1;
    }

    //get details of a book
    public entry fun get_book_details(bookstore: &mut Bookstore, book_id: u64): (u64, String, String, u64, bool) {
        //check if the book is available
        assert!(book_id <= bookstore.books.length(), EBookNotAvailable);

        let book = &bookstore.books[book_id];
        (book.book_id, book.title, book.description, book.price, book.sold)
    }

    //update price of book
    public entry fun update_book_price(bookstore: &mut Bookstore, owner: &AdminCap, book_id: u64, new_price: u64) {
        //make sure it's the admin performing the operation
        assert!(&owner.bookstore_id == object::uid_to_inner(&bookstore.id), ENotOwner);
        //make sure the book actually exists
        assert!(book_id <= bookstore.books.length(), EBookNotAvailable);
        
        let book = &mut bookstore.books[book_id];
        book.price = new_price;
    }

    //update description of a book
    public entry fun update_book_description(bookstore: &mut Bookstore, owner: &AdminCap, book_id: u64, description: String) {
        //make sure the book is available
        assert!(book_id <= bookstore.books.length(), EBookNotAvailable);
        
        //make sure it's the admin performing the operation
        assert!(&owner.bookstore_id == object::uid_to_inner(&bookstore.id), ENotOwner);
        let book = &mut bookstore.books[book_id];
        book.description = description;
    }

    //delist book from bookstore by marking it as sold
    public entry fun delist_book(
        bookstore: &mut Bookstore,
        owner: &AdminCap,
        book_id: u64
    ) {
        //make sure it's the admin performing the operation
        assert!(&owner.bookstore_id == object::uid_to_inner(&bookstore.id), ENotOwner);

        //check if the book is available
        assert!(book_id <= bookstore.books.length(), EBookNotAvailable);
        
        let book = &mut bookstore.books[book_id];
        book.sold = true;
    }

    //buy book
    public entry fun buy_book(
        bookstore: &mut Bookstore,
        book_id: u64,
        amount: Coin<SUI>,
    ) {
        //check if the book is available
        assert!(book_id <= bookstore.books.length(), EBookNotAvailable);

        //check if the book is already sold
        assert!(bookstore.books[book_id].sold == false, EBookNotAvailable);

        //get price
        let book = &bookstore.books[book_id];
        //ensure amount is equal to the price of the book
        assert!(coin::value(&amount) == book.price, ErrorInsufficientAmount);
    
        let coin_balance = coin::into_balance(amount);
        //add the amount to the bookstore balance
        balance::join(&mut bookstore.balance, coin_balance);
    }

    //owner withdraw profits
    public entry fun withdraw_funds(user_cap: &AdminCap, bookstore: &mut Bookstore, ctx: &mut TxContext) {
        //verify it's the owner of the bookstore
        assert!(object::uid_as_inner(&bookstore.id) == &user_cap.bookstore_id, ENotOwner);
        
        let amount: u64 = balance::value(&bookstore.balance);

        let amount_available: Coin<SUI> = coin::take(&mut bookstore.balance, amount, ctx);

        transfer::public_transfer(amount_available, tx_context::sender(ctx));
        event::emit(AmountWithdrawn {
            recipient: tx_context::sender(ctx),
            amount: amount
        });
    }
}
