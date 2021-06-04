pragma ton-solidity >= 0.41.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface IRepo {
    function onRootDeployed() external;
}
