pragma ton-solidity >= 0.36.0;
import "Types.sol";

interface IEventLog {
    function meet(uint16 id, address a) external;
    function logError(uint16 id, uint16 code) external;
    function logTransfer(uint32 id, uint16 from, uint16 to, uint32 val) external;
    function logRecord(uint16 id, int32 val) external;
    function logEvent(uint16 id, EventType eType, EventState s, uint32 eventID) external;
    function logDeploy(uint16 id, EventState s) external;

    function purgeAll() external;
}
