pragma solidity ^0.4.18;

import "../CompliantToken.sol";


contract CompliantTokenMock is CompliantToken {
    function CompliantTokenMock(address initialAccount, uint initialBalance) public {
        balances[initialAccount] = initialBalance;
        totalSupply_ = initialBalance;
    }
}
