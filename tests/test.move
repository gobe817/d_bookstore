#[test_only]
module bookstore::bookshop_tests {
    use sui::test_scenario::{Self as ts, Scenario, next_tx};
    use sui::test_utils::assert_eq;
    use sui::clock::{Self, Clock};
    use std::string::{Self, String};
    use sui::coin::{Self, Coin, mint_for_testing};
    use sui::sui::SUI;

    use std::debug::print;

    use bookstore::bookstore::{Self as bs, Shop, AdminCap, Book, test_init};

    const ADMIN: address = @0xe;
    const TEST_ADDRESS1: address = @0xeb;
    const TEST_ADDRESS2: address = @0xbb;
    const TEST_ADDRESS3: address = @0xbc;

    #[test]
    public fun test_init1() {
        let mut scenario_val: Scenario  = ts::begin(ADMIN);
        let scenario = &mut scenario_val;

        next_tx(scenario, ADMIN);
        {
            test_init(ts::ctx(scenario));
        };

        // create and list 
        next_tx(scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(scenario);
            let mut self = ts::take_shared<Shop>(scenario);

            let name = string::utf8(b"name1");
            let price: u64 = 1_000_000_000;
            let c = clock::create_for_testing(ts::ctx(scenario));

            let book = bs::new(&cap, name, price, &c, ts::ctx(scenario));
            let id = object::id(&book);
            print(&id);
            
            bs::list(&cap, &mut self, book, price);


            ts::return_to_sender(scenario, cap);
            ts::return_shared(self);
            c.share_for_testing();
        };

        let asset_id1 = object::last_created(ts::ctx(scenario));

        // ADDRESS2 is going to buy
        next_tx(scenario, TEST_ADDRESS2);
        {
            let mut self = ts::take_shared<Shop>(scenario);

            let name = string::utf8(b"name1");
            let price: u64 = 1_000_000_000;
            
            let coin_ = mint_for_testing<SUI>(1_000_000_000, ts::ctx(scenario));

            
            let item = bs::purchase(&mut self, asset_id1, coin_);
            transfer::public_transfer(item, TEST_ADDRESS2);

            ts::return_shared(self);
        };  

        // checkj that the user has book or not 
        next_tx(scenario, TEST_ADDRESS2);
        {
            let book = ts::take_from_sender<Book>(scenario);

            ts::return_to_sender(scenario, book);
        };

        // admin withdraw profits. 
        next_tx(scenario, ADMIN);
        {
            let cap = ts::take_from_sender<AdminCap>(scenario);
            let mut self = ts::take_shared<Shop>(scenario);
            let amount = 1_000_000_000;

            let coin = bs::withdraw_profits(&cap, &mut self, amount, ts::ctx(scenario));

            transfer::public_transfer(coin, ADMIN);
          
            ts::return_to_sender(scenario, cap);
            ts::return_shared(self);
        };

        ts::end(scenario_val);
    }
}

