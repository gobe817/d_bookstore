/// Module: bookshop
module bookstore::bookstore {
    use sui::tx_context::{sender};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock, timestamp_ms};
    use std::string::{String};
    use sui::dynamic_object_field as dof;
    use sui::dynamic_field as df;
    use sui::transfer_policy::{Self as tp, TransferRequest};
    use sui::package::{Self, Publisher};

    const EBookBuyAmountInvalid: u64 = 0;
    const EBookPriceNotChanged: u64 = 1;

    
    //AdminCap is the capability for admin role management
    public struct AdminCap has key {
        id: UID,
    }

    public struct BOOKSTORE has drop {}
    
    public struct Item has store, copy, drop { id: ID }

    public struct Listing has store, copy, drop { id: ID, is_exclusive: bool }

    public struct PublisherWrapper has key, store {
        id: UID,
        publisher: Publisher
    }

    // shared object based on kiosk
    public struct Shop has key {
        id: UID,
        owner: address,
        item_count: u64,
        balance: Balance<SUI>
    }

    // object for rent or buy 
    public struct Book has key, store {
        id: UID,
        inner: ID,
        name: String,
        price: u64,
        create_at: u64,
        update_at: u64,
    }

    fun init(otw:BOOKSTORE, ctx: &mut TxContext) {
        let admin_address = ctx.sender();
        let admin_cap = AdminCap {
            id: object::new(ctx)
        };
        transfer::transfer(admin_cap, admin_address);

        let shop = Shop {
            id: object::new(ctx),
            owner: sender(ctx),
            item_count:0,
            balance: balance::zero()
        };

         // define the publisher
        let publisher_ = package::claim<BOOKSTORE>(otw, ctx);
        // wrap the publisher and share.
        transfer::share_object(PublisherWrapper {
            id: object::new(ctx),
            publisher: publisher_
        });
        // transfer the admincap
        transfer::share_object(shop);
    }

    // create new book
    public fun new(
        _: &AdminCap,
        name_: String,
        price: u64,
        c: &Clock,
        ctx: &mut TxContext
    ) : Book {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);

        let book = Book {
            id: id_,
            inner: inner_,
            name: name_,
            price: price,
            create_at: timestamp_ms(c),
            update_at: timestamp_ms(c)
        };
        book
    }

    public fun new_name(self: &mut Book, name: String, clock: &Clock) {
        self.name = name;
        self.update_at = timestamp_ms(clock);
    }

    public fun new_price(self: &mut Book, price: u64, clock: &Clock, _ctx: &mut TxContext) {
        assert!(self.price != price, EBookPriceNotChanged);
        self.price = price;
        self.update_at = clock::timestamp_ms(clock);
    }

    public fun list(_: &AdminCap, self: &mut Shop, book: Book, price: u64) {
        let id_ = book.inner;
        place_internal(self, book);

        df::add(&mut self.id, Listing { id: id_, is_exclusive: false }, price);
    }

    public fun delist(_: &AdminCap, self: &mut Shop, id: ID) {
        df::remove<Listing, u64>(&mut self.id, Listing { id, is_exclusive: false });
    }

    public fun purchase<T: key + store>(self: &mut Shop, id: ID, payment: Coin<SUI>) : (Book, TransferRequest<T>) {
        let price = df::remove<Listing, u64>(&mut self.id, Listing { id, is_exclusive: false });
        let item = dof::remove<Item, Book>(&mut self.id, Item { id });

        self.item_count = self.item_count - 1;
        assert!(price == payment.value(), EBookBuyAmountInvalid);
        coin::put(&mut self.balance, payment);

        (item, tp::new_request(id, price, object::id(self)))
    }

    public fun withdraw_profits(_: &AdminCap, self: &mut Shop, amount: u64, ctx: &mut TxContext) : Coin<SUI> {
        coin::take(&mut self.balance, amount, ctx)
    }

    public fun GetShopInfoPayAddress(self: &Shop): address {
        self.owner
    }

    public fun GetBookCount(self: &Book): u64 {
        self.price
    }

    public fun GetBookId(self: &Book): ID {
        self.inner
    }

    fun place_internal(self: &mut Shop, book: Book) {
        self.item_count = self.item_count + 1;
        dof::add(&mut self.id, Item { id: object::id(&book) }, book)
    }

    public fun new_policy<T>(_: &AdminCap, publish: &PublisherWrapper, ctx: &mut TxContext ) {
        // set the publisher
        let publisher = get_publisher(publish);
        // create an transfer_policy and tp_cap
        let (transfer_policy, tp_cap) = tp::new<T>(publisher, ctx);
        // transfer the objects 
        transfer::public_transfer(tp_cap, ctx.sender());
        transfer::public_share_object(transfer_policy);
    }

    fun get_publisher(shared: &PublisherWrapper) : &Publisher {
        &shared.publisher
     }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        let otw = BOOKSTORE {};
        init(otw, ctx);
    }
}

