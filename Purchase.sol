// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.4;
contract Purchase {
    uint public value;
    uint public confirmPurchaseTime; // New variable to store time at which confirmPurchase function is called.
    address payable public seller;
    address payable public buyer;

    enum State { Created, Locked, Release, Inactive }
    // The state variable has a default value of the first member, `State.Created`
    State public state;

    modifier condition(bool condition_) {
        require(condition_);
        _;
    }

    /// Only the buyer can call this function.
    error OnlyBuyer();
    /// Only the seller can call this function.
    error OnlySeller();
    /// The function cannot be called at the current state.
    error InvalidState();
    /// The provided value has to be even.
    error ValueNotEven();

    modifier onlyBuyer() {
        if (msg.sender != buyer)
            revert OnlyBuyer();
        _;
    }

    modifier onlySeller() {
        if (msg.sender != seller)
            revert OnlySeller();
        _;
    }

    modifier inState(State state_) {
        if (state != state_)
            revert InvalidState();
        _;
    }

    // New modifiers for completePurchase function. lockedState is derived from inState modifier.
    modifier lockedState() {
        if (state != State.Locked)
            revert InvalidState();
        _;
    }

    // The buyer can call completePurchase without having to wait an alotted time. The seller has to wait 5 minutes before calling it.
    modifier onlyBuyerOrTimeElapsed(uint _time) {
        require (msg.sender == buyer || block.timestamp >= (_time + 5 minutes)); 
        _;
    }

    event Aborted();
    event PurchaseConfirmed();
    event ItemReceived();
    event SellerRefunded();

    // Ensure that `msg.value` is an even number.
    // Division will truncate if it is an odd number.
    // Check via multiplication that it wasn't an odd number.
    constructor() payable {
        seller = payable(msg.sender);
        value = msg.value / 2;
        if ((2 * value) != msg.value)
            revert ValueNotEven();
    }

    /// Abort the purchase and reclaim the ether.
    /// Can only be called by the seller before
    /// the contract is locked.
    function abort()
        external
        onlySeller
        inState(State.Created)
    {
        emit Aborted();
        state = State.Inactive;
        // We use transfer here directly. It is
        // reentrancy-safe, because it is the
        // last call in this function and we
        // already changed the state.
        seller.transfer(address(this).balance);
    }

    /// Confirm the purchase as buyer.
    /// Transaction has to include `2 * value` ether.
    /// The ether will be locked until confirmReceived
    /// is called.
    function confirmPurchase()
        external
        inState(State.Created)
        condition(msg.value == (2 * value))
        payable
    {
        emit PurchaseConfirmed();
        confirmPurchaseTime = block.timestamp; // Variable will be passed into onlyBuyerOrTimeElapsed modifier.
        buyer = payable(msg.sender);
        state = State.Locked;
    }

    /// This new function combines confirmReceived (for buyer) and refundSeller (for seller)
    /// functions.
    function completePurchase()
        external
        lockedState
        onlyBuyerOrTimeElapsed(confirmPurchaseTime)
    {
        emit ItemReceived();
        emit SellerRefunded();
        state = State.Inactive;

        buyer.transfer(value);
        seller.transfer(address(this).balance);
    }
}