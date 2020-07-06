pragma solidity ^0.4.21;

import "../CompliantToken.sol";


contract CompliantTokenMock is CompliantToken {
    constructor(address _owner, uint initialBalance)
        public 
        MintableToken(_owner)
        Validator()
    {
        balances[_owner] = initialBalance;
        totalSupply_ = initialBalance;
    }
}
