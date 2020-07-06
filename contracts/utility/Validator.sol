pragma solidity ^0.4.21;


/**
 * @title Validator
 * @dev The Validator contract has a validator address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Validator {
    address public validator;

    event NewValidatorSet(address indexed previousOwner, address indexed newValidator);

    /**
    * @dev The Validator constructor sets the original `validator` of the contract to the sender
    * account.
    */
    function Validator() public {
        validator = msg.sender;
    }

    /**
    * @dev Throws if called by any account other than the validator.
    */
    modifier onlyValidator() {
        require(msg.sender == validator);
        _;
    }

    /**
    * @dev Allows the current validator to transfer control of the contract to a newValidator.
    * @param newValidator The address to become next validator.
    */
    function setNewValidator(address newValidator) public onlyValidator {
        require(newValidator != address(0));
        emit NewValidatorSet(validator, newValidator);
        validator = newValidator;
    }
}
