pragma ton-solidity >= 0.41.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "Types.sol";

interface IMedium {
    function registerTokenWallet(uint16 id) external;
    function registerOwner(uint16 id, uint16 walletId, address walletAddress) external;

    function propose(EventType eType, uint32 value) external;
    function approve(uint32 eventID) external;
    function reject(uint32 eventID) external;

    function requestTransfer(address to, uint32 val) external;
    function processTransfer(address to, uint32 val) external;
    function accrue(uint32 val) external;
}
