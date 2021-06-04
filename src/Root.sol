pragma ton-solidity >= 0.41.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "Types.sol";
import "Medium.sol";
import "Base.sol";
import "IRoot.sol";
import "IRepo.sol";
import "OwnerWallet.sol";
import "TokenWallet.sol";


contract Root is IRoot, Base {

    uint16 static _version;
    address static _deployer;

    struct WalletInfo {
        uint16 id;
        uint128 tonBalance;
        uint key;
        uint32 createdAt;
        uint32 updatedAt;
    }

    uint128 _initialBalance = 2 ton;
    uint128 _refillValue = 2 ton;
    uint32 _updateTimeout = 60 seconds;

    uint16 _nextOwnerID = OWNER_BASE_ID;
    uint16 _nextWalletID = TOKEN_BASE_ID;

    uint[] _ownerKeys;
    mapping (uint8 => Code) public images;
    mapping (address => WalletInfo) public _roster;
    
    modifier onchain {
        require(msg.sender != address(0));
        _;
    }
    
    modifier self {
        require(msg.sender == address(this));
        _;
    }

    modifier onlyDeployer {
        require(msg.sender == _deployer);
        _;
    }

    modifier accept {
        tvm.accept();
        _;
    }

    constructor(uint[] ownerKeys) public onchain onlyDeployer {
        _ownerKeys = ownerKeys;
        IRepo(_deployer).onRootDeployed{value: REIMBURSE}();
    }

    function _deploy(uint8 n, TvmCell constructorCall, uint key) private view returns (address) {
        Code image = images[n];
        TvmCell deployable = tvm.buildStateInit({
            code: image.code,
            pubkey: key
        });

        if (n == 2 && _medium != address(0))
            return address(0);
        if ((n == 3 || n == 4) && _roster.exists(address(tvm.hash(deployable))))
            return address(0);

        uint128 val = uint128(image.tons) * 1e9;
        return tvm.deploy(deployable, constructorCall, val, 0);
    }

    function deployUAX(Code medium, Code owner, Code wallet) external override onlyDeployer {
        images[2] = medium;
        images[3] = owner;
        images[4] = wallet;
        this.deployReserve{value: REIMBURSE}();
        this.deployOwners{value: REIMBURSE}();
    }

    function deployReserve() external self {
        _medium = _deploy(2, tvm.encodeBody(Medium), tvm.pubkey());
    }
    
    function deployOwners() external self {
        for (uint pubkey: _ownerKeys) {
            (uint16 wid, address waddr) = _deployTokenWallet(pubkey);
            (uint16 oid, address oaddr) = _deployOwner(pubkey, wid, waddr);
            _roster[waddr] = WalletInfo(wid, _initialBalance, pubkey, uint32(now), uint32(now));
            _roster[oaddr] = WalletInfo(oid, _initialBalance, pubkey, uint32(now), uint32(now));
        }
    }

    function _deployTokenWallet(uint pubkey) 
    private returns (uint16 wid, address waddr) {
        wid = _nextWalletID++;
        waddr = _deploy(3, tvm.encodeBody(TokenWallet, wid, _medium), pubkey);
    }

    function _deployOwner(uint pubkey, uint16 wid, address waddr) 
    private returns (uint16 oid, address oaddr) {
        oid = _nextOwnerID++;
        oaddr = _deploy(4, tvm.encodeBody(OwnerWallet, oid, _medium, wid, waddr), pubkey);
    }

    function deployTokenWalletsWithKeys(uint[] keys) external override accept returns (address[] addrs) {
        for (uint key: keys) {
            (, address addr) = _deployTokenWallet(key);
            addrs.push(addr);
        }
    }

    function updateTonBalance(uint64 tonBalance) external override {
        address from = msg.sender;
        uint32 delta = uint32(now) - _roster[from].updatedAt;
        if (delta >= _updateTimeout) {
            if (tonBalance < _warnBalance) {
                msg.sender.transfer(_refillValue, false, 1);
            }
            _roster[from].tonBalance = tonBalance;
            _roster[from].updatedAt = uint32(now);
        }
    }

    function updateRefillConfig(uint64 initialBalance, uint64 warnBalance, uint64 refillValue, uint32 updateTimeout) external override {
        _initialBalance = initialBalance;
        _warnBalance = warnBalance;
        _refillValue = refillValue;
        _updateTimeout = updateTimeout;
    }
}
