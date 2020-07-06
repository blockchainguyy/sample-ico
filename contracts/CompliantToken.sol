pragma solidity ^0.4.18;

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
        bool isTransferFrom;
    }

    mapping (uint => TransactionStruct) public pendingTransactions;
    mapping (address => mapping (address => uint256)) public pendingApprovalAmount;
    uint256 public currentNonce = 0;
    uint256 public transferFee;
    address public feeRecipient;    

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
        bool isTransferFrom
    );

    event WhiteListingContractSet(address indexed _whiteListingContract);

    event FeeSet(uint256 indexed previousFee, uint256 indexed newFee);

    event FeeRecipientSet(address indexed previousRecipient, address indexed newRecipient);

    function setWhitelistContract(address whitelistAddress) public onlyValidator {
        require(whitelistAddress != address(0));
        whiteListingContract = Whitelist(whitelistAddress);
        WhiteListingContractSet(whiteListingContract);
    }

    function setFee(uint256 fee) public onlyValidator {
        FeeSet(transferFee, fee);
        transferFee = fee;
    }

    function setFeeRecipient(address recipient) public onlyValidator {
        require(recipient != address(0));
        FeeRecipientSet(feeRecipient, recipient);
        feeRecipient = recipient;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value > 0);
        require(whiteListingContract.isInvestorApproved(msg.sender));
        require(whiteListingContract.isInvestorApproved(_to));

        (msg.sender == feeRecipient) ? 
            require(_value <= balances[msg.sender]) : 
            require(_value.add(transferFee) <= balances[msg.sender]);

        pendingTransactions[currentNonce] = TransactionStruct(
            msg.sender,
            _to,
            _value,
            transferFee,
            false
        );

        RecordedPendingTransaction(msg.sender, _to, _value, transferFee, false);
        currentNonce++;

        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_from != address(0));
        require(_to != address(0));
        require(_value > 0);
        require(whiteListingContract.isInvestorApproved(msg.sender));
        require(whiteListingContract.isInvestorApproved(_from));
        require(whiteListingContract.isInvestorApproved(_to));
        
        if (_from == feeRecipient) {
            require(_value.add(pendingApprovalAmount[_from][_to]) <= balances[_from]);
            require(_value.add(pendingApprovalAmount[_from][_to]) <= allowed[_from][_to]);
            pendingApprovalAmount[_from][_to] = pendingApprovalAmount[_from][_to].add(_value);
        } else {
            require(_value.add(pendingApprovalAmount[_from][_to]).add(transferFee) <= balances[_from]);
            require(_value.add(pendingApprovalAmount[_from][_to]).add(transferFee) <= allowed[_from][_to]);
            pendingApprovalAmount[_from][_to] = pendingApprovalAmount[_from][_to].add(_value).add(transferFee);
        }

        pendingTransactions[currentNonce] = TransactionStruct(
            _from,
            _to,
            _value,
            transferFee,
            true
        );

        RecordedPendingTransaction(_from, _to, _value, transferFee, true);
        currentNonce++;

        return true;
    }

    function approveTransfer(uint256 nonce) public onlyValidator returns (bool) {
        require(pendingTransactions[nonce].to != address(0));
        require(whiteListingContract.isInvestorApproved(pendingTransactions[nonce].from));
        require(whiteListingContract.isInvestorApproved(pendingTransactions[nonce].to));

        if (pendingTransactions[nonce].from == feeRecipient) {
            balances[pendingTransactions[nonce].from] = balances[pendingTransactions[nonce].from]
                .sub(pendingTransactions[nonce].value);
            balances[pendingTransactions[nonce].to] = balances[pendingTransactions[nonce].to]
                .add(pendingTransactions[nonce].value);
            
            TransferWithFee(
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
            
            TransferWithFee(
                pendingTransactions[nonce].from,
                pendingTransactions[nonce].to,
                pendingTransactions[nonce].value,
                pendingTransactions[nonce].fee
            );
        }

        Transfer(
                pendingTransactions[nonce].from,
                pendingTransactions[nonce].to,
            pendingTransactions[nonce].value
            );

        if (pendingTransactions[nonce].isTransferFrom) {
            if (pendingTransactions[nonce].from == feeRecipient) {
                allowed[pendingTransactions[nonce].from][pendingTransactions[nonce].to] = allowed[pendingTransactions[nonce].from][pendingTransactions[nonce].to]
                    .sub(pendingTransactions[nonce].value);
                pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].to] = pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].to]
                    .sub(pendingTransactions[nonce].value);
            } else {
                allowed[pendingTransactions[nonce].from][pendingTransactions[nonce].to] = allowed[pendingTransactions[nonce].from][pendingTransactions[nonce].to]
                    .sub(pendingTransactions[nonce].value).sub(pendingTransactions[nonce].fee);
                pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].to] = pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].to]
                    .sub(pendingTransactions[nonce].value).sub(pendingTransactions[nonce].fee);
            }
        }

        delete pendingTransactions[nonce];
        return true;
    }

    function rejectTransfer(uint256 nonce, uint256 reason) public onlyValidator {
        require(pendingTransactions[nonce].to != address(0));
        
        if (pendingTransactions[nonce].isTransferFrom) {
            if (pendingTransactions[nonce].from == feeRecipient) {
                pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].to] = pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].to]
                    .sub(pendingTransactions[nonce].value);
            } else {
                pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].to] = pendingApprovalAmount[pendingTransactions[nonce].from][pendingTransactions[nonce].to]
                    .sub(pendingTransactions[nonce].value).sub(pendingTransactions[nonce].fee);
            }
        }
        
        TransferRejected(
            pendingTransactions[nonce].from,
            pendingTransactions[nonce].to,
            pendingTransactions[nonce].value,
            nonce,
            reason
        );
        
        delete pendingTransactions[nonce];
    }
}
