pragma solidity ^0.4.23;

import "../CompliantToken.sol";


contract CompliantTokenMock is CompliantToken {
    constructor(
        address _owner,
        uint initialBalance,
        address whitelistAddress,
        address recipient,
        uint256 fee
    )
        public 
        CompliantToken(_owner, whitelistAddress, recipient, fee)
    {
        balances[_owner] = initialBalance;
        totalSupply_ = initialBalance;
    }
}
