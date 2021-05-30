pragma ton-solidity >= 0.36.0;

interface IConsole {
    function initConsole(address eventLog, address root, address medium, uint16 logLevel) external;
}
