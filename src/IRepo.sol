pragma ton-solidity >= 0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface IRepo {
    function onRootDeployed() external;
}
