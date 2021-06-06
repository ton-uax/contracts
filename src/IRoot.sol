pragma ton-solidity >= 0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "Types.sol";

interface IRoot {
    function deployUAX(Code medium, Code owner, Code wallet) external;

    function updateTonBalance(uint64 tonBalance) external;
    function updateRefillConfig(uint64 initialBalance, uint64 warnBalance, uint64 refillValue, uint32 updateTimeout) external;

    function deployTokenWalletsWithKeys(uint[] keys) external returns (address[] addrs);
}
