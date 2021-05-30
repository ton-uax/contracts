pragma msgValue 4e7;
pragma ton-solidity >= 0.36.0;
import "Base.sol";
import "IEventLog.sol";
import "IRoot.sol";
import "IMedium.sol";
import "IOwnerWallet.sol";
import "ITokenWallet.sol";

/* Primary Token Exchange contract */
contract Medium is Base, IMedium  {

    uint32 _transferCount;      // all transfers
    uint32 _walletCount;
    uint32 _totalSupply;
    uint32 _accruedFee;
    uint32 _totalFeeClaimed;
    uint32 _eventCount;
    uint8 _ownerCount;

    mapping (uint32 => Event) public _onApproval;
    mapping (uint32 => Event) public _archived;

    enum ProposalState { Undefined, Init, Requested, OnApproval, Approved, Confirmed, Committed, Done, Failed, Expired, Rejected, Last }
    enum Triage { Undefined, Checking, Confirmed, Approved, Success, NotFound,  Unauthorized, DoubleSigned, Failure, Expired, Rejected, Last }

    struct TokenWalletRecord {
        uint32 balance;
        address addr;
        uint32 lastAccessed;
    }

    struct Proposal {
        uint32 id;
        EventType eType;
        uint32 createdAt;
        uint32 validUntil;
        uint32 confirmedAt;
        ProposalState state;
        uint8 signsAt;
        uint16 signs;
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
        if (id != CONSOLE_ID && id != MEDIUM_ID) {
            _error(id, REQUIRES_COLLECTIVE_DECISION); // 123 Unauthorized attempt to control emission without overall agreement
            return;
        }
        tvm.accept();
        _;
    }

    modifier echo {
        if (msg.sender != address(this)) {
            uint16 id = _clients[msg.sender];
            _error(id, CALLS_BY_THIS_CONTRACT_ONLY); // 120 Can be called by this contract only
            return;
        }
        tvm.accept();
        _;
    }

    modifier owner {
        uint16 id = _clients[msg.sender];
        if (id >= TOKEN_BASE_ID) {
            _error(id, UNAUTHORIZED_OPERATION); // 124 Unauthorized attempt to control emission
            return;
        }
        if (id > OWNER_BASE_ID + _ownerCount) {
            _error(id, SYSTEM_OWNER_EMULATION); // 125 Emulating owner actions
        }
        _;
    }

    /* Helpers */
    function _addClient(uint16 id, address a) private inline {
        _clients[a] = id;
        IEventLog(_eventLog).meet(id, a);
        address addr = _ledger[id].addr;
        if (addr.value == 0) {
            _ledger[id] = TokenWalletRecord(0, a, uint32(now));
            _walletCount++;
        } else if (addr != a) {
            _error(id, WALLET_ADDRESS_MISMATCH);
        } else {
            if (_logLevel & LOG_DEPLOYS > 0)
                IEventLog(_eventLog).logDeploy{value: LOG}(id, EventState.Approved);
        }
    }

    function _logRecord(int32 value) private view {
        if (_logLevel & LOG_RECORDS > 0)
            IEventLog(_eventLog).logRecord{value: LOG}(_id, value);
    }

    function _logEvent(uint16 id, EventType et, EventState es) private view {
        if (_logLevel & LOG_EVENTS > 0)
            IEventLog(_eventLog).logEvent{value: LOG}(id, et, es, _eventCount);
    }

    function _logTransfer(uint16 from, uint16 to, uint32 val) private view {
        if (_logLevel & LOG_TRANSFERS > 0)
            IEventLog(_eventLog).logTransfer{value: LOG}(_transferCount, from, to, val);
    }

    /* Register freshly deployed Token Wallet */
    function registerTokenWallet(uint16 id, address a) external override {
        _addClient(id, a);
        if (_logLevel & LOG_DEPLOYS > 0)
                IEventLog(_eventLog).logDeploy{value: LOG}(id, EventState.Committed);
    }

    function registerOwner(uint8 ownerId, uint16 id, address a, uint16 tid, address ta) external override {
        if (id >= OWNER_BASE_ID && id < CONSOLE_ID) {
            _owners[ownerId] = OwnerInfo(id, tid, a, ta, uint32(now));
            _ownerCount++;
            _addClient(id, a);
            _addClient(tid, ta);
        }
    }
    /* Token transfer tracking */

    function _gain(uint32 val) private {
        _ledger[MEDIUM_ID].balance += val;

        if (_logLevel & LOG_RECORDS > 0)
            _logRecord(int32(val));
    }

    function _lose(uint32 val) private {
        if (_ledger[MEDIUM_ID].balance < val)
            _error(_id, INSUFFICIENT_SUPPLY); // 217 Not enough funds to deduce from Medium
        else
            _ledger[MEDIUM_ID].balance -= val;

        if (_logLevel & LOG_RECORDS > 0)
            _logRecord(int32(-val));
    }

    // Intermediate token transfer routine
    // Called by the transfer interface functions
    // Calls the current default transfer routine
    function _checkTransfer(address afrom, address ato, uint32 val) private returns (uint32) {
        tvm.accept();
        uint16 idfrom = _clients[afrom];
        uint16 idto = _clients[ato];
        if (idfrom == 0)
            _error(idfrom, UNKNOWN_TRANSFER_ORIGIN);
        if (idto == 0)
            _error(idto, UNKNOWN_TRANSFER_TARGET);
        return _transfer1(idfrom, idto, val);
    }

    // One-step transfer
    function _transfer1(uint16 from, uint16 to, uint32 val) private returns (uint32) {
        _transferCount++;
        uint32 total = from >= TOKEN_BASE_ID ? val + _transferFee : val;
        if (_ledger[from].balance < total) {
            _error(from, INSUFFICIENT_BALANCE); // 215 Not enough funds to perform transfer
            return 0;
        }
        if (from >= TOKEN_BASE_ID) {
            _accruedFee += _transferFee;
        }
        // update balances
        _ledger[from].balance -= total;
        _ledger[to].balance += val;
        if (_logLevel & LOG_TRANSFERS > 0) {
            _logTransfer(from, to, val);
        }
        return total;
    }

    /* User token wallet to user token wallet */
    function requestTransfer(address to, uint32 val) external override {
        uint32 total = _checkTransfer(msg.sender, to, val);
        if (total == 0) {
            // error
        } else {
            // notify parties
            ITokenWallet(msg.sender).debit(total);
            ITokenWallet(to).credit(val);
        }
    }

    function processTransfer(address to, uint32 val) external override {
        uint32 total = _checkTransfer(msg.sender, to, val);
        if (total == 0) {
            // error
            ITokenWallet(msg.sender).abort(val);
            ITokenWallet(to).withdraw(val);
        } else {
            ITokenWallet(msg.sender).collect(total);
            ITokenWallet(to).pay(val);
        }
    }

    function accrue(uint32 val) external override {
        address from = msg.sender;
        // uint16 id = _clients[from];
        uint32 total = _checkTransfer(from, address(this), val);
        if (total == 0) {
            // error
        } else {
            // _ledger[id].balance -= val;
            ITokenWallet(from).debit(total);
            // _gain(val);
        }
    }

    function updateTransferFee(uint8 val) external voted {
        _transferFee = val;
        // notify all
    }

    function claimTransferFee(uint16 id, uint32 val) external voted {
        if (!_ledger.exists(id)) {
            _error(id, UNKNOWN_ACCRUED_TRANSFER_TARGET); // 351 Target of accrued fee transfer is not listed as a Medium client
        } else if (val > _accruedFee) {
            _error(id, REQUESTED_FEE_EXCEEDS_ACCRUED); // 350 Requested amount of transfer fee exceeds the accrued value
        } else {
            _totalFeeClaimed += val;
            _accruedFee -= val;
            this.creditOwner(id, val);
        }
    }

    /* Change the total tokens supply by the specified amount */
    function mint(uint16 id, uint32 val) external voted {
        _gain(val);
        _totalSupply += val;
        _logEvent(id, EventType.Mint, id > 0 ? EventState.Done : EventState.Failed);
    }

    /* Reduce the total tokens supply by the specified amount */
    function burn(uint16 id, uint32 val) external voted {
        if (val > _ledger[MEDIUM_ID].balance)
            _error(id, INSUFFICIENT_TOTAL_SUPPLY); // 218 Amount to burn exceeds total supply
        else {
            _totalSupply -= val;
            _lose(val);
        }
        _logEvent(id, EventType.Burn, id > 0 ? EventState.Done : EventState.Failed);
    }

    function withdraw(uint16 id, uint32 val) external voted {
        if (val > _totalSupply)
            _error(id, INSUFFICIENT_TOTAL_SUPPLY); // 218 Amount to burn exceeds total supply
        else {
            _totalSupply -= val;
            _lose(val);
            this.creditOwner(id, val);
        }
        _logEvent(id, EventType.Withdraw, id > 0 ? EventState.Done : EventState.Failed);
    }

    function creditOwner(uint16 id, uint32 val) external voted {
        _ledger[id].balance += val;
        ITokenWallet(_ledger[id].addr).credit(val);
    }

    /* Decision making center */

    function approve(uint32 eventID) external override owner {
        uint16 id = _clients[msg.sender];
        uint8 ownerId = uint8(id - OWNER_BASE_ID);
        uint16 mask = uint16(1) << ownerId;
        optional(Event) eo = _onApproval.fetch(eventID);
        Triage st = Triage.Checking;
        if (id == CONSOLE_ID) {
            st = Triage.Approved;
        } else if (ownerId == 0) {
            st = Triage.NotFound;
        } else if (eo.hasValue()) {
            Event ie = eo.get();
            Proposal p = _proposals[ie.id];
            if (p.validUntil < now) {
                st = Triage.Expired;
            }
            for (uint i = 0; i < p.signsAt; i++) {
                if (p.signs & mask > 0) {
                    st = Triage.DoubleSigned;
                    break;
                }
            }

            if (st < Triage.Success) {
                _proposals[ie.id].signsAt++;
                _proposals[ie.id].signs |= mask;
                st = Triage.Approved;
                if (_proposals[ie.id].signsAt >= p.signsReq) {
                    st = Triage.Confirmed;
                    this.commit(eventID, EventState.Confirmed);
                }
            } else if (st > Triage.Failure) {
                this.commit(eventID, EventState.Rejected);
            }
            _logEvent(id, ie.eType, ie.state);
        }
    }

    function reject(uint32 eventID) external override owner {
        uint16 id = _clients[msg.sender];
        optional(Event) eo = _onApproval.fetch(eventID);
        if (eo.hasValue()) {
            Event e = eo.get();
            this.commit(eventID, EventState.Rejected);
            _logEvent(id, e.eType, e.state);
        }
    }

    function propose(EventType eType, uint32 value) external override owner {
        uint16 id = _clients[msg.sender];
        
        if (_currentEvent.state == EventState.OnApproval && _proposals[_currentEvent.id].validUntil < now) {
            delete _currentEvent;
        }
        if (_currentEvent.state > EventState.Undefined && _currentEvent.state < EventState.Committed) {
            // error
            return;
        }

        _currentEvent = Event(++_eventCount, eType, EventState.Undefined, uint32(now));
        _transit(EventState.Requested);
        uint32 eid = _eventCount;
        uint8 ownerId = uint8(id - OWNER_BASE_ID);
        uint16 signs = uint16(1) << ownerId;
        _proposals[eid] = Proposal(eid, eType, uint32(now), uint32(now + 70 seconds), 0,
            ProposalState.OnApproval, 1, signs, 2/*_ownerCount*/, value, _owners[ownerId].tokenWalletId);
        _onApproval[eid] = _currentEvent;
        _transit(EventState.OnApproval);
    }

    function _execute(Event e) private view {
        Proposal p = _proposals[e.id];

        if (e.eType == EventType.Mint)
            this.mint(p.actor, p.value);
        else if (e.eType == EventType.Burn)
            this.burn(p.actor, p.value);
        else if (e.eType == EventType.Withdraw)
            this.withdraw(p.actor, p.value);
        else if (e.eType == EventType.SetTransferFee)
            this.updateTransferFee(uint8(p.value));
        else if (e.eType == EventType.ClaimTransferFee)
            this.claimTransferFee(p.actor, p.value);
        else
            _error(p.actor, UNKNOWN_EVENT_TYPE); // 130 Unknown event type

        _logEvent(p.actor, e.eType, e.state);
    }

    function _transit(EventState st) private {
        _currentEvent.state = st;
        this.notifyOwners(st);
    }

    function commit(uint32 eventID, EventState st) external echo {
        optional(Event) eo = _onApproval.fetch(eventID);
        if (eo.hasValue()) {
            Event e = eo.get();
            _proposals[eventID].confirmedAt = uint32(now);
            _transit(st);
            _logEvent(_id, e.eType, e.state);
            if (st == EventState.Confirmed) {
                _execute(e);
            }
            _archived[e.id] = e;
            delete _onApproval[eventID];
            delete _currentEvent;
        }
    }

    function notifyOwners(EventState st) external echo view {
        for ((, OwnerInfo oi) : _owners) {
            IOwnerWallet(oi.addr).updateEventState(_eventCount, st);
        }
    }

    function supplyImproved() external view returns (uint32 twTotal, uint32 owTotal, uint32 feeTotal, uint32 unallocated) {
        for ((uint16 id, TokenWalletRecord twr): _ledger) {
            if (id >= OWNER_BASE_ID && id < CONSOLE_ID)
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
