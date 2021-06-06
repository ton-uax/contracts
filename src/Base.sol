pragma ton-solidity >= 0.36.0;
import "IRoot.sol";

contract Base {

    uint64 constant PROCESS = 4e7;
    uint64 constant COMPUTE = 1e8;
    uint64 constant REIMBURSE = 3e8;

    uint16 constant OWNER_BASE_ID   = 1;
    uint16 constant ROOT_ID         = 30;
    uint16 constant MEDIUM_ID       = 40;
    uint16 constant TOKEN_BASE_ID   = 1e4;

    /*  Authorization errors */
    uint16 constant ADDRESS_NOT_REGISTERED          = 113; // Address requesting token transfer is not registered
    uint16 constant MEDIUM_ACCESS_DENIED            = 114; // Address requesting Medium management action is not an owner
    uint16 constant ROOT_ACCESS_DENIED              = 117; // Unauthorized attempt to configure the Root
    uint16 constant WALLET_ACCESS_DENIED            = 118; // Unauthorized attempt to configure the user wallet token contract
    uint16 constant REQUIRES_OWNER_SIGNATURE        = 119; // Requires owner's signature to operate
    uint16 constant CALLS_BY_THIS_CONTRACT_ONLY     = 120; // Can be called by this contract only
    uint16 constant UNAUTHORIZED_CONTRACT_ACCESS    = 122; // Unauthorized attempt to access the contract
    uint16 constant REQUIRES_COLLECTIVE_DECISION    = 123; // Unauthorized attempt to control emission without overall agreement
    uint16 constant UNAUTHORIZED_OPERATION          = 124; // Unauthorized attempt to control emission
    uint16 constant SYSTEM_OWNER_EMULATION          = 125; // Emulating owner actions
    uint16 constant UNKNOWN_EVENT_TYPE              = 130; // Unknown event type

    uint16 constant INVALID_TYPE_ON_DEPLOY          = 150; //  Invalid list index on deploy

    uint16 constant NO_TOKENS_FOR_SALE_CURRENTLY    = 200; // No offering to sell tokens at this time
    uint16 constant NOT_AUTHORIZED_TO_BUY_TOKENS    = 201; // Not authorized to buy tokens
    uint16 constant OUT_OF_STOCK                    = 202; // No tokens are available for purchase
    uint16 constant ILLEGAL_TRANSFER_CONFIRMATION   = 203; // Not authorized to confirm transfers
    uint16 constant ILLEGAL_FUNDS_DEDUCTION         = 204; // Not authorized to deduct funds
    uint16 constant ILLEGAL_TRANSFER_ATTEMPT        = 205; // Not authorized to initiate transfers
    uint16 constant ILLEGAL_TRANSFER_REJECT         = 206; // Not authorized to reject transfers
    uint16 constant WALLET_ID_MISMATCH              = 207; // Wallet ID does not match client records
    uint16 constant WALLET_ADDRESS_MISMATCH         = 208; // Wallet ID does not match ledger records
    uint16 constant WALLET_ID_SETUP_MISMATCH        = 210; // Wallet ID supplied on setup does not match the original ID
    uint16 constant WALLET_ID_POST_DEPLOY_MISMATCH  = 211; // Wallet ID supplied on deploy does not match the original ID
    uint16 constant WALLET_KEY_POST_DEPLOY_MISMATCH = 212; // Wallet key supplied on deploy does not match the original key
    uint16 constant WALLET_CREATION_TIME_MISMATCH   = 213; // Wallet creation time is in the future
    uint16 constant INSUFFICIENT_BALANCE            = 215; // Not enough funds to perform transfer
    uint16 constant WALLET_BALANCE_OVERRUN          = 216; // Not enough funds to complete transfer
    uint16 constant INSUFFICIENT_SUPPLY             = 217; // Not enough funds to deduce from Medium
    uint16 constant INSUFFICIENT_TOTAL_SUPPLY       = 218; // Amount to burn exceeds total supply

    uint16 constant UNKNOWN_TRANSFER_ORIGIN         = 230; // Initiator of transfer is not listed as a Medium client
    uint16 constant UNKNOWN_TRANSFER_TARGET         = 231; // Target of transfer is not listed as a Medium client
    uint16 constant UNREGISTERED_TRANSFER_ORIGIN    = 232; // Origin of transfer is not registered in the Medium ledger
    uint16 constant UNREGISTERED_TRANSFER_TARGET    = 233; // Target of transfer is not registered in the Medium ledger
    uint16 constant TRANSFER_ORIGIN_MISMATCH        = 234; // Origin of transfer does not match the records
    uint16 constant TRANSFER_TARGET_MISMATCH        = 235; // Target of transfer does not match the records

    uint16 constant BUDGET_DEFICIENCY               = 300; //  Reported overall balance is below recorded value
    uint16 constant BUDGET_OVERRUN                  = 301; //  Reported overall balance exceeds recorded value
    uint16 constant FAILED_TO_COMPLETE_EVENT        = 321; //  Failed to complete event

    uint16 constant LOOKUP_FAILED                   = 333; // No ID found for this address

    uint16 constant REQUESTED_FEE_EXCEEDS_ACCRUED   = 350; // Requested amount of transfer fee exceeds the accrued value
    uint16 constant UNKNOWN_ACCRUED_TRANSFER_TARGET = 351; // Target of accrued fee transfer is not listed as a Medium client

    uint16 constant OWNER_WALLET_EXISTS             = 400; // Owner wallet with this key has been already deployed
    uint16 constant TOKEN_WALLET_EXISTS             = 401; // Token wallet with this key has been already deployed
    uint16 constant BALANCE_UPDATE_TIMEOUT          = 402; // Balance update has been requested recently

    uint16 public _id;
    address public _root;
    address public _medium;

    uint8 _transferFee      = 1;
    uint64 _warnBalance     = 1.99 ton;

    mapping (address => uint16) public _clients;
    
    function _checkTonBalance() internal view {
        uint64 tonBalance = uint64(address(this).balance);
        if (tonBalance < _warnBalance) {
            IRoot(_root).updateTonBalance{value: PROCESS}(tonBalance);
        }
    }

    function initMember(uint16 id, address root, address medium) external {
        _id = id;
        _root = root;
        _medium = medium;
        _clients[root] = ROOT_ID;
        _clients[medium] = MEDIUM_ID;
    }

}
