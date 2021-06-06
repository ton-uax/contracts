pragma ton-solidity >= 0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

interface ITokenWallet {

    function transferTokens(address to, uint32 val) external view;
    function instantTransfer(address to, uint32 val) external;
    function donate(uint32 val) external view;

    function credit(uint32 val) external;
    function debit(uint32 val) external;

    function incur(uint32 val) external;

    function collect(uint32 val) external;
    function pay(uint32 val) external;
    function abort(uint32 val) external;
    function withdraw(uint32 val) external;
}
