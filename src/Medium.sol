pragma msgValue 4e7;
pragma ton-solidity >= 0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "Base.sol";
import "IRoot.sol";
import "IMedium.sol";
import "IOwnerWallet.sol";
import "ITokenWallet.sol";


contract Medium is Base, IMedium  {

    uint32 _transferCount;
    uint32 _walletCount;
    
    uint32 _totalSupply;

    uint32 _accruedFee;
    uint32 _totalFeeClaimed;

    uint32 _eventCount;
    uint8 _ownerCount;

    enum ProposalState { Undefined, Init, Requested, OnApproval, Approved, Confirmed, Committed, Done, Failed, Expired, Rejected, Last }

    struct TokenWalletRecord {
        uint32 balance;
        address addr;
        uint32 lastAccessed;
    }

    struct Proposal {
        uint32 id;
        EventType eType;

        uint32 createdAt;
        uint32 expireAt;
        uint32 resolvedAt;

        ProposalState state;

        uint8 signsAt;
        uint16 signsMask;
        uint8 signsReq;

        uint32 value;
        uint16 actor;
    }

    mapping (uint32 => Proposal) public _proposals;
    Event public _currentEvent;

    mapping (uint16 => TokenWalletRecord) public _ledger;

    struct OwnerInfo {
        uint16 clientId;
        uint16 tokenWalletId;
        address addr;
        address tokenWalletAddr;
        uint32 createdAt;
    }

    mapping (uint8 => OwnerInfo) public _owners;

    modifier voted {
        uint16 id = _clients[msg.sender];
        // 123 Unauthorized attempt to control emission without overall agreement
        require(id == MEDIUM_ID, REQUIRES_COLLECTIVE_DECISION);
        tvm.accept();
        _;
    }

    modifier self {
        // 120 Can be called by this contract only
        require(msg.sender == address(this), CALLS_BY_THIS_CONTRACT_ONLY);
        tvm.accept();
        _;
    }

    modifier owner {
        uint16 id = _clients[msg.sender];
        require((id >= OWNER_BASE_ID) && (id < OWNER_BASE_ID + _ownerCount), UNAUTHORIZED_OPERATION);
        // 124 Unauthorized attempt to control emission
        _;
    }

    function _addClient(uint16 id, address a) inline private {
        _clients[a] = id;
        address addr = _ledger[id].addr;
        if (addr.value == 0)
            _ledger[id] = TokenWalletRecord(0, a, uint32(now));
    }

    function registerTokenWallet(uint16 id) external override {
        _addClient(id, msg.sender);
        _walletCount++;
    }

    function registerOwner(uint16 id, uint16 walletId, address walletAddress) external override {
        require((id >= OWNER_BASE_ID) && (id < ROOT_ID), UNAUTHORIZED_OPERATION);
        if (_ownerCount == 0)
            _addClient(MEDIUM_ID, address(this));
        _owners[_ownerCount++] = OwnerInfo(id, walletId, msg.sender, walletAddress, uint32(now));
        _addClient(id, msg.sender);
    }

    function _gain(uint32 val) private {
        _ledger[MEDIUM_ID].balance += val;
    }

    function _lose(uint32 val) private {
        require(_ledger[MEDIUM_ID].balance >= val, INSUFFICIENT_SUPPLY);
        // 217 Not enough funds to deduce from Medium
        _ledger[MEDIUM_ID].balance -= val;

    }

    // Intermediate token transfer routine
    // Called by the transfer interface functions
    // Calls the current default transfer routine
    function _checkTransfer(address afrom, address ato, uint32 val) private returns (uint32) {
        tvm.accept();
        uint16 idfrom = _clients[afrom];
        uint16 idto = _clients[ato];

        require(idfrom != 0, UNKNOWN_TRANSFER_ORIGIN);
        require(idto != 0, UNKNOWN_TRANSFER_TARGET);
        return _transfer1(idfrom, idto, val);
    }

    // One-step transfer
    function _transfer1(uint16 from, uint16 to, uint32 val) private returns (uint32) {
        _transferCount++;
        uint32 total = val + _transferFee;
        if (_ledger[from].balance < total) {
            // 215 Not enough funds to perform transfer
            return 0;
        }
        _accruedFee += _transferFee;

        _ledger[from].balance -= total;
        _ledger[to].balance += val;
        return total;
    }

    /* User token wallet to user token wallet */
    function requestTransfer(address to, uint32 val) external override {
        uint32 total = _checkTransfer(msg.sender, to, val);
        require(total > 0, INSUFFICIENT_BALANCE);
        ITokenWallet(msg.sender).debit(total);
        ITokenWallet(to).credit(val);
    }

    function processTransfer(address to, uint32 val) external override {
        uint32 total = _checkTransfer(msg.sender, to, val);
        if (total > 0) {
            // confirm payment
            ITokenWallet(msg.sender).collect(total);
            ITokenWallet(to).pay(val);
        } else {
            // revert payment
            ITokenWallet(msg.sender).abort(total);
            ITokenWallet(to).withdraw(val);
        }
    }

    function accrue(uint32 val) external override {
        uint32 total = _checkTransfer(msg.sender, address(this), val);
        require(total > 0, INSUFFICIENT_BALANCE); 
        ITokenWallet(msg.sender).debit(total);
    }

    function updateTransferFee(uint8 val) external voted {
        _transferFee = val;
    }

    function claimTransferFee(uint16 id, uint32 val) external voted {
        require (_ledger.exists(id), UNKNOWN_ACCRUED_TRANSFER_TARGET);
        // 351 Target of accrued fee transfer is not listed as a Medium client
        require(val <= _accruedFee, REQUESTED_FEE_EXCEEDS_ACCRUED); 
        // 350 Requested amount exceeds the accrued value
        _totalFeeClaimed += val;
        _accruedFee -= val;

        _ledger[id].balance += val;
        ITokenWallet(_ledger[id].addr).credit(val);
    }

    function mint(uint32 val) external voted {
        _gain(val);
        _totalSupply += val;
    }

    function burn(uint32 val) external voted {
        _lose(val);
        _totalSupply -= val;   
    }

    function withdraw(uint16 id, uint32 val) external voted {
        _lose(val);
        _ledger[id].balance += val;
        ITokenWallet(_ledger[id].addr).credit(val);
    }

    function approve(uint32 eventID) external override owner {
        require(_currentEvent.id != 0 && _currentEvent.id == eventID);
        Proposal p = _proposals[_currentEvent.id];

        uint16 id = _clients[msg.sender];
        uint8 ownerId = uint8(id - OWNER_BASE_ID);
        uint16 senderMask = uint16(1) << ownerId;
        uint16 senderVoted = p.signsMask & senderMask;

        require((senderVoted == 0) && (p.resolvedAt == 0));
        
        if (p.resolvedAt == 0 && p.expireAt < now) {
            delete _currentEvent;
            tvm.exit();
        }
    
        p.signsAt += 1;
        p.signsMask |= senderMask;
        _proposals.replace(eventID, p);
        if (p.signsAt >= p.signsReq)
            this.commit(eventID, EventState.Confirmed);
    }

    function reject(uint32 eventID) external override owner {
        require((_currentEvent.id != 0) && (_currentEvent.id == eventID));
        Proposal p = _proposals[_currentEvent.id];
        if ( (p.resolvedAt == 0) && (p.expireAt < now) ) {
            p.resolvedAt = now;
            delete _currentEvent;
            tvm.exit();
        }
        this.commit(eventID, EventState.Rejected);
    }

    function propose(EventType eType, uint32 value) external override owner {
        // don't accept new proposals when current one is still unresolved 
        Proposal p = _proposals[_currentEvent.id];
        if ( (p.id > 0) && (p.resolvedAt == 0) && (now > p.expireAt) ) {
            p.resolvedAt = now;
            delete _currentEvent;
        }
        require(_currentEvent.id == 0);

        uint16 id = _clients[msg.sender];
        uint8 ownerId = uint8(id - OWNER_BASE_ID);
        uint32 eid = ++_eventCount;
        
        _currentEvent = Event(eid, eType, EventState.OnApproval, uint32(now));
        _proposals[eid] = Proposal(
            eid, eType, 
            uint32(now), uint32(now + 2 minutes), 0,
            ProposalState.OnApproval, 
            1, uint16(1) << ownerId, 2, 
            value, _owners[ownerId].tokenWalletId);

        this.notifyOwners(_currentEvent);
    }

    function commit(uint32 eventID, EventState st) external self {
        require((_currentEvent.id != 0) && (_currentEvent.id == eventID));
        _currentEvent.state = st;

        Proposal p = _proposals[_currentEvent.id];
        p.resolvedAt = uint32(now);
        _proposals.replace(_currentEvent.id, p);
        
        if (st == EventState.Confirmed) {
            _execute(p);
        }

        this.notifyOwners(_currentEvent);
        delete _currentEvent;
    }

    function _execute(Proposal p) inline private pure {
        if (p.eType == EventType.Mint)
            this.mint(p.value);
        else if (p.eType == EventType.Burn)
            this.burn(p.value);
        else if (p.eType == EventType.Withdraw)
            this.withdraw(p.actor, p.value);
        else if (p.eType == EventType.SetTransferFee)
            this.updateTransferFee(uint8(p.value));
        else if (p.eType == EventType.ClaimTransferFee)
            this.claimTransferFee(p.actor, p.value);
    }

    function notifyOwners(Event e) external self view {
        for ((, OwnerInfo oi) : _owners) {
            IOwnerWallet(oi.addr).updateEventState(e.id, e.state);
        }
    }

    function supplyImproved() external view returns (uint32 twTotal, uint32 owTotal, uint32 feeTotal, uint32 unallocated) {
        for ((uint16 id, TokenWalletRecord twr): _ledger) {
            if (id >= OWNER_BASE_ID && id < OWNER_BASE_ID + _ownerCount)
                owTotal += twr.balance;
            else if (id == MEDIUM_ID)
                unallocated += twr.balance;
            else if (id >= TOKEN_BASE_ID)
                twTotal += twr.balance;
        }
        feeTotal = _accruedFee;
    }

    function getStats() external view returns (uint32 transfers, uint32 supply, uint32 wallets, uint8 transferFee, uint32 accruedFee, uint32 totalFeeClaimed) {
        transfers = _transferCount;
        supply = _totalSupply;
        wallets = _walletCount;
        transferFee = _transferFee;
        accruedFee = _accruedFee;
        totalFeeClaimed = _totalFeeClaimed;
    }
}
