pragma ton-solidity >= 0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "Types.sol";

interface IOwnerWallet {
    function updateEventState(uint32 id, EventState state) external;

    function approve(uint32 id) external;
    function reject(uint32 id) external;
    function propose(EventType eType, uint32 value) external;
}
