pragma solidity ^0.4.21;

import "../zeppelin-solidity/contracts/token/ERC20/MintableToken.sol";
import "./utility/Validator.sol";
import "./WhitelistContract.sol";


contract CompliantToken is Validator, MintableToken {
    Whitelist public whiteListingContract;

    struct TransactionStruct {
        address from;
        address to;
        uint256 value;
        uint256 fee;
        address spender;
    }

    mapping (uint => TransactionStruct) public pendingTransactions;
    mapping (address => mapping (address => uint256)) public pendingApprovalAmount;
    uint256 public currentNonce = 0;
    uint256 public transferFee;
    address public feeRecipient;

    modifier checkIsInvestorApproved(address _account) {
        require(whiteListingContract.isInvestorApproved(_account));
        _;
    }

    modifier checkIsAddressValid(address _account) {
        require(_account != address(0));
        _;
    }

    modifier checkIsValueValid(uint256 _value) {
        require(_value > 0);
        _;
    }

    event TransferRejected(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 indexed nonce,
        uint256 reason
    );

    event TransferWithFee(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 fee
    );

    event RecordedPendingTransaction(
        address indexed from,
        address indexed to,
        uint256 value,
        uint256 fee,
        address spender
    );

    event WhiteListingContractSet(address indexed _whiteListingContract);

    event FeeSet(uint256 indexed previousFee, uint256 indexed newFee);

    event FeeRecipientSet(address indexed previousRecipient, address indexed newRecipient);

    function setWhitelistContract(address whitelistAddress) external
        onlyValidator
        checkIsAddressValid(whitelistAddress)
    {
        whiteListingContract = Whitelist(whitelistAddress);
        emit WhiteListingContractSet(whiteListingContract);
    }

    function setFee(uint256 fee) external onlyValidator {
        emit FeeSet(transferFee, fee);
        transferFee = fee;
    }

    function setFeeRecipient(address recipient) external
        onlyValidator
        checkIsAddressValid(recipient)
    {
        emit FeeRecipientSet(feeRecipient, recipient);
        feeRecipient = recipient;
    }

    function transfer(address _to, uint256 _value) public
        checkIsAddressValid(_to)
        checkIsInvestorApproved(msg.sender)
        checkIsInvestorApproved(_to)
        checkIsValueValid(_value)
        returns (bool)
    {
        (msg.sender == feeRecipient) ? 
            require(_value <= balances[msg.sender]) : 
            require(_value.add(transferFee) <= balances[msg.sender]);

        pendingTransactions[currentNonce] = TransactionStruct(
            msg.sender,
            _to,
            _value,
            transferFee,
            address(0)
        );

        emit RecordedPendingTransaction(msg.sender, _to, _value, transferFee, address(0));
        currentNonce++;

        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public 
        checkIsAddressValid(_from)
        checkIsAddressValid(_to)
        checkIsInvestorApproved(msg.sender)
        checkIsInvestorApproved(_from)
        checkIsInvestorApproved(_to)
        checkIsValueValid(_value)
        returns (bool)
    {
        if (_from == feeRecipient) {
            require(_value.add(pendingApprovalAmount[_from][msg.sender]) <= balances[_from]);
            require(_value.add(pendingApprovalAmount[_from][msg.sender]) <= allowed[_from][msg.sender]);
            pendingApprovalAmount[_from][msg.sender] = pendingApprovalAmount[_from][msg.sender].add(_value);
        } else {
            require(_value.add(pendingApprovalAmount[_from][msg.sender]).add(transferFee) <= balances[_from]);
            require(_value.add(pendingApprovalAmount[_from][msg.sender]).add(transferFee) <= allowed[_from][msg.sender]);
            pendingApprovalAmount[_from][msg.sender] = pendingApprovalAmount[_from][msg.sender].add(_value).add(transferFee);
        }

        pendingTransactions[currentNonce] = TransactionStruct(
            _from,
            _to,
            _value,
            transferFee,
            msg.sender
        );

        emit RecordedPendingTransaction(_from, _to, _value, transferFee, msg.sender);
        currentNonce++;

        return true;
    }

    function approveTransfer(uint256 nonce) external 
        onlyValidator 
        checkIsAddressValid(pendingTransactions[nonce].from)
        checkIsAddressValid(pendingTransactions[nonce].to)
        checkIsInvestorApproved(pendingTransactions[nonce].from)
        checkIsInvestorApproved(pendingTransactions[nonce].to)
        returns (bool)
    {
        if (pendingTransactions[nonce].from == feeRecipient) {
            balances[pendingTransactions[nonce].from] = balances[pendingTransactions[nonce].from]
                .sub(pendingTransactions[nonce].value);
            balances[pendingTransactions[nonce].to] = balances[pendingTransactions[nonce].to]
                .add(pendingTransactions[nonce].value);

            emit TransferWithFee(
                pendingTransactions[nonce].from,
                pendingTransactions[nonce].to,
                pendingTransactions[nonce].value,
                0
            );
        } else {
            balances[pendingTransactions[nonce].from] = balances[pendingTransactions[nonce].from]
                .sub(pendingTransactions[nonce].value.add(pendingTransactions[nonce].fee));
            balances[pendingTransactions[nonce].to] = balances[pendingTransactions[nonce].to]
                .add(pendingTransactions[nonce].value);
            balances[feeRecipient] = balances[feeRecipient].add(pendingTransactions[nonce].fee);

            emit TransferWithFee(
                pendingTransactions[nonce].from,
                pendingTransactions[nonce].to,
                pendingTransactions[nonce].value,
                pendingTransactions[nonce].fee
            );
        }

        emit Transfer(
            pendingTransactions[nonce].from,
            pendingTransactions[nonce].to,
            pendingTransactions[nonce].value
        );
        
        if (pendingTransactions[nonce].spender != 0x0) {
            if (pendingTransactions[nonce].from == feeRecipient) {
                allowed[pendingTransactions[nonce].from][pendingTransactions[nonce].spender] = allowed[pendingTransactions[nonce].from][pendingTransactions[nonce].spender]
                    .sub(pendingTransactions[nonce].value);
                pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].spender] = pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].spender]
                    .sub(pendingTransactions[nonce].value);
            } else {
                allowed[pendingTransactions[nonce].from][pendingTransactions[nonce].spender] = allowed[pendingTransactions[nonce].from][pendingTransactions[nonce].spender]
                    .sub(pendingTransactions[nonce].value).sub(pendingTransactions[nonce].fee);
                pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].spender] = pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].spender]
                    .sub(pendingTransactions[nonce].value).sub(pendingTransactions[nonce].fee);
            }
        }

        delete pendingTransactions[nonce];
        return true;
    }

    function rejectTransfer(uint256 nonce, uint256 reason) external 
        onlyValidator
        checkIsAddressValid(pendingTransactions[nonce].from)
    {        
        if (pendingTransactions[nonce].spender != address(0)) {
            if (pendingTransactions[nonce].from == feeRecipient) {
                pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].spender] = pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].spender]
                    .sub(pendingTransactions[nonce].value);
            } else {
                pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].spender] = pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].spender]
                    .sub(pendingTransactions[nonce].value).sub(pendingTransactions[nonce].fee);
            }
        }
        
        emit TransferRejected(
            pendingTransactions[nonce].from,
            pendingTransactions[nonce].to,
            pendingTransactions[nonce].value,
            nonce,
            reason
        );
        
        delete pendingTransactions[nonce];
    }
}
