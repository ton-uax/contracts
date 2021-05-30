pragma ton-solidity >= 0.36.0;
import "Types.sol";

interface IMedium {
    function registerTokenWallet(uint16 id, address a) external;
    function registerOwner(uint8 ownerId, uint16 id, address a, uint16 tid, address ta) external;

    function propose(EventType eType, uint32 value) external;
    function approve(uint32 eventID) external;
    function reject(uint32 eventID) external;

    function requestTransfer(address to, uint32 val) external;
    function processTransfer(address to, uint32 val) external;
    function accrue(uint32 val) external;
}
