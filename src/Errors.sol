pragma ton-solidity >= 0.36.0;

contract Errors {

    // operation
    // transfer:
    // Invalid/unknown/Unauthorized
    // source/target
    // /id/address

    // operation: byte 0
    uint8 constant TRANSFER = 1;    // send, mint, burn, buy tokens
    uint8 constant QUERY    = 2;    // query property
    uint8 constant CHANGE   = 4;    // set property: fee/emission
    uint8 constant ACCESS   = 8;    // other
    uint8 constant DEPLOY   = 16;   // deploy
    uint8 constant REGISTER = 32;   // acquaint with

    // stage: byte 1 (>> 8)
    uint8 constant INITIAL = 1;     // Created
    uint8 constant REQUEST = 2;     // Sent
    uint8 constant ACTION  = 4;     // 1-phase action: send
    uint8 constant RESULT  = 8;     // 1-phase result: receive
    uint8 constant CONFIRM = 16;    // 2-phase action: confirm
    uint8 constant DENY    = 32;    // 2-phase action: deny
    uint8 constant DONE    = 64;    // outcome: success
    uint8 constant FAILED  = 128;   // outcome: failure

    // type: byte 2 (>> 16)
    uint8 constant INVALID  = 1;     // Input values do not match
    uint8 constant UNKNOWN  = 2;     // Does not match the system records
    uint8 constant ILLEGAL  = 4;     // Is not allowed to
    uint8 constant IMPROPER = 8;     // State does not match
    uint8 constant UNTIMELY = 16;    // Time is not right
    uint8 constant BOGUS    = 32;    // Not affecting anything

    // Role: byte 3 (>>24)
    uint8 constant SOURCE   = 1;    // active: who
    uint8 constant TARGET   = 2;    // passive: on/to whom
    uint8 constant CONTEXT  = 4;    // medium: where
    uint8 constant REPORTER = 8;    // aloof: witness

    // component: byte 4 (>>32)
    uint8 constant ID      = 1;
    uint8 constant ADDRESS = 2;
    uint8 constant VALUE   = 4;

    // category: byte 5 (>> 40)
    uint8 constant GLOBAL   = 1;
    uint8 constant SYSTEM   = 2;
    uint8 constant USER     = 4;
    uint8 constant OTHER    = 8;

    // value mismatch: byte 6 (>> 48)

    // addresses
    uint8 constant NON_STD  = 1;
    uint8 constant ZERO     = 2;

    function _checkTransfer(address from, address to, uint64 errorCode) private returns (uint64) {
        return _checkSource(from) | _checkTarget(to) | TRANSFER;
    }

    function _checkSource(address from, uint64 errorCode) private returns (uint64) {
        return _checkAddress(from) | _checkId(from) | SOURCE * uint64(1) >> 24;
    }

    function _checkTarget(address to, uint64 errorCode) private returns (uint64) {
        return _checkAddress(to) | _checkId(to) | TARGET * uint64(1) >> 24;
    }

    function _checkAddress(address addr, uint64 errorCode) private returns (uint64) {
        return _checkAddressValue(addr) & INVALID & ADDRESS * uint64(1) >> 32;
    }

    function _checkAddressValue(address addr, uint64 errorCode) private returns (uint64) {
        return addr.isAddrStd() & NON_STD * uint64(1) >> 48 | * uint64(1) >>  && !addr.
    }
    /*  Authorization errors */
    uint16 constant ADDRESS_NOT_REGISTERED            = 113; // Address requesting token transfer is not registered
    uint16 constant MEDIUM_ACCESS_DENIED              = 114; // Address requesting Medium management action is not an owner
    uint16 constant ROOT_ACCESS_DENIED                = 117; // Unauthorized attempt to configure the Root
    uint16 constant WALLET_ACCESS_DENIED              = 118; // Unauthorized attempt to configure the user wallet token contract
    uint16 constant CALLS_BY_THIS_CONTRACT_ONLY       = 120; // Can be called by this contract only
    uint16 constant UNAUTHORIZED_CONTRACT_ACCESS      = 122; // Unauthorized attempt to access the contract
    uint16 constant REQUIRES_COLLECTIVE_DECISION      = 123; // Unauthorized attempt to control emission without overall agreement
    uint16 constant UNKNOWN_EVENT_TYPE                = 130; // Unknown event type

    uint16 constant INVALID_TYPE_ON_DEPLOY            = 150; //  Invalid list index on deploy

    uint16 constant NO_TOKENS_FOR_SALE_CURRENTLY      = 200; // No offering to sell tokens at this time
    uint16 constant NOT_AUTHORIZED_TO_BUY_TOKENS      = 201; // Not authorized to buy tokens
    uint16 constant OUT_OF_STOCK                      = 202; // No tokens are available for purchase
    uint16 constant ILLEGAL_TRANSFER_CONFIRMATION     = 203; // Not authorized to confirm transfers
    uint16 constant ILLEGAL_FUNDS_DEDUCTION           = 204; // Not authorized to deduct funds
    uint16 constant ILLEGAL_TRANSFER_ATTEMPT          = 205; // Not authorized to initiate transfers
    uint16 constant ILLEGAL_TRANSFER_REJECT           = 206; // Not authorized to reject transfers

    uint16 constant BUDGET_DEFICIENCY                 = 300; //  Reported overall balance is below recorded value
    uint16 constant BUDGET_OVERRUN                    = 301; //  Reported overall balance exceeds recorded value
    uint16 constant FAILED_TO_COMPLETE_EVENT          = 321; //  Failed to complete event
}
