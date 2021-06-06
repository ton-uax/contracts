pragma ton-solidity >= 0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

struct Code {
    TvmCell code;
    uint16 tons;
    string name;
}

enum EventType { Undefined, Mint, Burn, Withdraw, SetTransferFee, ClaimTransferFee, Reserved, Last }
enum EventState { Undefined, Requested, OnApproval, Approved, Confirmed, Committed, Done, Failed, Expired, Rejected, Last }

struct Event {
    uint32 id;
    EventType eType;
    EventState state;
    uint32 createdAt;
}
