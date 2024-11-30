#[test_only]
module bookstore::bookshop_tests {
    use sui::test_scenario::{Self as ts, Scenario, next_tx};
    use sui::test_utils::assert_eq;
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};
    use sui::coin::{Self, Coin, mint_for_testing};
    use sui::sui::SUI;
    use sui::transfer_policy::{Self as tp, TransferPolicy};

    use std::debug::print;

    use bookstore::bookstore::{Self as bs, Shop, AdminCap, Book, test_init, PublisherWrapper};

    const ADMIN: address = @0xe;
    const TEST_ADDRESS1: address = @0xeb;
    const TEST_ADDRESS2: address = @0xbb;

    #[test]
    public fun test_init1() {
        let mut scenario_val: Scenario = ts::begin(ADMIN);
        let scenario = &mut scenario_val;

        // Initialize the bookstore
        next_tx(scenario, ADMIN);
        {
            test_init(ts::ctx(scenario));
        };

        // Set up transfer policy for books
        next_tx(scenario, ADMIN);
        {
            helper_new_policy<Book>(scenario);
        };

        // Create and list a book
        let book_id;
        next_tx(scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(scenario);
            let mut shop = ts::take_shared<Shop>(scenario);

            let name = string::utf8(b"name1");
            let price: u64 = 1_000_000_000;
            let clock = clock::create_for_testing(ts::ctx(scenario));

            let book = bs::new(&cap, name, price, &clock, ts::ctx(scenario));
            book_id = object::id(&book);

            bs::list(&cap, &mut shop, book, price);

            ts::return_to_sender(scenario, cap);
            ts::return_shared(shop);
            clock.share_for_testing();
        };

        // Test purchase by TEST_ADDRESS2
        next_tx(scenario, TEST_ADDRESS2);
        {
            let mut shop = ts::take_shared<Shop>(scenario);
            let policy = ts::take_shared<TransferPolicy<Book>>(scenario);

            let payment = mint_for_testing<SUI>(1_000_000_000, ts::ctx(scenario));
            let (book, request) = bs::purchase<Book>(&mut shop, book_id, payment);

            tp::confirm_request<Book>(&policy, request);
            transfer::public_transfer(book, TEST_ADDRESS2);

            ts::return_shared(policy);
            ts::return_shared(shop);
        };

        // Verify that TEST_ADDRESS2 owns the book
        next_tx(scenario, TEST_ADDRESS2);
        {
            let book = ts::take_from_sender<Book>(scenario);
            assert_eq!(book.name, string::utf8(b"name1"));
            ts::return_to_sender(scenario, book);
        };

        // Admin withdraw profits
        next_tx(scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(scenario);
            let mut shop = ts::take_shared<Shop>(scenario);
            let amount = 1_000_000_000;

            let profits = bs::withdraw_profits(&cap, &mut shop, amount, ts::ctx(scenario));
            transfer::public_transfer(profits, ADMIN);

            ts::return_to_sender(scenario, cap);
            ts::return_shared(shop);
        };

        ts::end(scenario_val);
    }

    public fun helper_new_policy<T>(scenario: &mut Scenario) {
        next_tx(scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(scenario);
            let publisher = ts::take_shared<PublisherWrapper>(scenario);

            bs::new_policy<T>(&admin_cap, &publisher, ts::ctx(scenario));

            ts::return_to_sender(scenario, admin_cap);
            ts::return_shared(publisher);
        };
    }
}
