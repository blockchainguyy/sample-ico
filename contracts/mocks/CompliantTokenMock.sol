pragma solidity ^0.4.23;

import "../CompliantToken.sol";


contract CompliantTokenMock is CompliantToken {
    constructor(address _owner, uint initialBalance)
        public 
        CompliantToken(_owner)
    {
        balances[_owner] = initialBalance;
        totalSupply_ = initialBalance;
    }
}
