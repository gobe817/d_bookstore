# Store Management Module for Bookstore

This module is designed for managing transactions in a bookstore using the Sui framework. It provides functionalities to handle customer-bookstore interactions, such as purchasing books, handling disputes, fulfilling orders, and managing escrow payments.

## Features

1. **Book Transactions**: Facilitates the creation, fulfillment, and completion of book transactions.
2. **Escrow Management**: Escrow funds are held during the transaction and can be released to the bookstore or refunded to the customer based on the outcome.
3. **Dispute Resolution**: Allows customers to raise disputes, which can be resolved in favor of the bookstore or the customer.
4. **Book Reviews**: Customers can leave reviews for books after a successful transaction.
5. **Refunds**: Customers can request refunds if the transaction is not fulfilled or disputed.
6. **Rating System**: Customers can rate their experience with the bookstore.

## Contract Structure

The contract consists of two main structures:
- **Transaction**: Represents the state of a transaction for purchasing books.
- **BookReview**: Represents a customer review of a purchased book.

## Error Codes

- `EInvalidTransaction`: Invalid transaction (e.g., accepting an already accepted transaction).
- `EInvalidBook`: Invalid book for the transaction.
- `EDispute`: Raised when a customer wants to dispute the transaction.
- `EAlreadyResolved`: The dispute is already resolved.
- `ENotStore`: Raised when the sender is not the bookstore or the customer.
- `EInvalidRefundRequest`: Invalid refund request (e.g., transaction fulfilled or in dispute).
- `EDeadlinePassed`: The transaction deadline has passed.
- `EInsufficientEscrow`: Insufficient funds in escrow.

## Key Functions

### Transaction Creation
```move
create_transaction(book: vector<u8>, quantity: u64, price: u64, clock: &Clock, duration: u64, open: vector<u8>, ctx: &mut TxContext)
```
Creates a new transaction where a customer initiates the purchase of a book.

### Accept Transaction
```move
accept_transaction(transaction: &mut Transaction, ctx: &mut TxContext)
```
The bookstore accepts the transaction.

### Fulfill Transaction
```move
fulfill_transaction(transaction: &mut Transaction, clock: &Clock, ctx: &mut TxContext)
```
The bookstore marks the transaction as fulfilled.

### Dispute Transaction
```move
dispute_transaction(transaction: &mut Transaction, ctx: &mut TxContext)
```
Allows the customer to dispute a transaction.

### Resolve Dispute
```move
resolve_dispute(transaction: &mut Transaction, resolved: bool, ctx: &mut TxContext)
```
Resolves a dispute in favor of either the customer (refund) or the bookstore (release payment).

### Release Payment
```move
release_payment(transaction: &mut Transaction, clock: &Clock, review: vector<u8>, ctx: &mut TxContext)
```
Releases the escrow payment to the bookstore after successful fulfillment of the transaction and records a book review.

### Cancel Transaction
```move
cancel_transaction(transaction: &mut Transaction, ctx: &mut TxContext)
```
Cancels the transaction, refunding escrow to the customer if necessary.

### Rate Store
```move
rate_store(transaction: &mut Transaction, rating: u64, ctx: &mut TxContext)
```
Allows customers to rate the bookstore after completing a transaction.

## How to Use

1. **Create a Transaction**: The customer initiates a transaction by calling `create_transaction` with the desired book, quantity, price, and transaction details.
2. **Accept and Fulfill**: The bookstore accepts the transaction using `accept_transaction` and then fulfills it by calling `fulfill_transaction`.
3. **Dispute**: If the customer is unsatisfied, they can raise a dispute with `dispute_transaction`.
4. **Resolve Dispute**: Once a dispute is raised, it can be resolved by either refunding the customer or releasing the payment to the bookstore with `resolve_dispute`.
5. **Complete Transaction**: After successful completion, the customer can release payment using `release_payment` and leave a review for the book.

## Escrow Management

Escrow is handled through the SUI balance mechanism. Funds are locked in escrow during the transaction and are released to the bookstore or refunded to the customer, depending on the fulfillment or dispute resolution process.

## Installation & Setup

1. Install the Sui Move framework: [Sui Documentation](https://docs.sui.io/)
2. Clone this repository into your project:
   ```bash
   git clone https://github.com/your-repo/store-management-bookstore
   ```
3. Compile and deploy the module using Sui's `move` CLI:
   ```bash
   sui move build
   ```

## Contribution

Feel free to contribute to this module by opening issues or submitting pull requests. For major changes, please open an issue to discuss the proposed changes first.

## License

This project is licensed under the MIT License.# d_bookstore
