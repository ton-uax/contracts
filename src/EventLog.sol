pragma ton-solidity >= 0.36.0;
import "Base.sol";
import "IEventLog.sol";

contract EventLog is Base, IEventLog {

    struct XS {
        uint32 id;
        uint16 sentBy;
        uint32 ts;
    }

    struct TransferS {
        uint16 from;
        uint16 to;
        uint32 val;
        uint32 tid;
    }

    struct RecordS {
        uint16 id;
        int32 val;
    }

    struct ErrorS {
        uint16 id;
        uint16 code;
    }

    struct EventS {
        uint16 id;
        EventType eType;
        EventState s;
        uint32 eventID;
    }

    struct DeployS {
        uint16 id;
        EventState s;
    }

    uint32 _x;

    mapping (uint32 => ErrorS) public _errors;
    mapping (uint32 => TransferS) public _transfers;
    mapping (uint32 => RecordS) public _records;
    mapping (uint32 => EventS) public _events;
    mapping (uint32 => DeployS) public _deploys;

    XS[] public _log;

    modifier log {
        _;
        _log.push(XS(_x++, _clients[msg.sender], uint32(now)));
    }

    function meet(uint16 id, address addr) external override {
        _clients[addr] = id;
    }

    function logError(uint16 id, uint16 code) external override log {
        _errors[_x] = ErrorS(id, code);
    }

    function logTransfer(uint32 tid, uint16 from, uint16 to, uint32 val) external override log {
        _transfers[_x] = TransferS(from, to, val, tid);
    }

    function logRecord(uint16 id, int32 val) external override log {
        _records[_x] = RecordS(id, val);
    }

    function logEvent(uint16 id, EventType eType, EventState s, uint32 eventID) external override log {
        _events[_x] = EventS(id, eType, s, eventID);
        if (s == EventState.Failed) {
            this.logError{value: LOG}(id, FAILED_TO_COMPLETE_EVENT); // 321  Failed to complete the requested event
        }
    }

    function logDeploy(uint16 id, EventState s) external override log {
        _deploys[_x] = DeployS(id, s);
    }

    function getAll() external view returns (mapping (uint32 => ErrorS) errors, mapping (uint32 => TransferS) transfers, mapping (uint32 => RecordS) records, mapping (uint32 => EventS) events, mapping (uint32 => DeployS) deploys) {
        errors = _errors;
        transfers = _transfers;
        records = _records;
        events = _events;
        deploys = _deploys;
    }

    function getErrorsExt() external view returns (ErrorS[] errors, XS[] details) {
        for ((uint32 x, ErrorS error): _errors) {
            errors.push(error);
            details.push(_log[x]);
        }
    }

    function purgeAll() external override {
        delete _errors;
        delete _transfers;
        delete _records;
        delete _events;
        delete _deploys;
        delete _log;
    }
}
