pragma ton-solidity >= 0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "Types.sol";
import "Root.sol";
import "IRepo.sol";
import "IRoot.sol";


abstract contract Utils {

    modifier accept {
        tvm.accept();
        _;
    }

    modifier offchain {
        require(msg.sender == address(0), 101);
        _;
    }

    modifier onchain {
        require(msg.value > 0, 102);
        _;
    }
    
    modifier onlyDev {
        require(msg.pubkey() == tvm.pubkey(), 103);
        _;
    }

    modifier onlyAddress(address addr) {
        require(msg.sender == addr, 104);
        _;
    }

}


contract Repo is Utils, IRepo {

    uint64 constant REIMBURSE = 3e8;

    uint16 public version;
    mapping (uint8 => Code) public repo;
    mapping (uint8 => address) public deployed;

    constructor() public offchain onlyDev accept {}

    function _makeRootDeployParams(Code root) private inline view returns (TvmCell deployable, uint128 balance) {        
        deployable = tvm.buildStateInit({
            contr: Root,
            code: root.code,
            pubkey: tvm.pubkey(),
            varInit: {
                _version: version,
                _deployer: address(this)
            }
        });
        balance = uint128(root.tons) * 1e9;
    }

    function calcRootAddress() public view returns (address root) {
        Code rootImg = repo[1];
        (TvmCell stateInit, ) = _makeRootDeployParams(rootImg);
        root = address(tvm.hash(stateInit));
    }

    function deployRoot(uint[] ownerKeys) public view offchain accept returns (address rootAddr) {
        Code root = repo[1];
        (TvmCell stateInit, uint128 balance) = _makeRootDeployParams(root);
        rootAddr = new Root {
            stateInit: stateInit,
            value: balance
        }(ownerKeys);
    }

    function onRootDeployed() external override onlyAddress(calcRootAddress()) accept {
        address root = msg.sender;
        deployed[1] = root;
        IRoot(root).deployUAX{value: REIMBURSE}(repo[2], repo[3], repo[4]);
    }

    function uploadCode(uint8 index, Code image) public offchain onlyDev accept {
        repo[index] = image;
    }

    function transfer(address addr, uint128 value) external pure offchain onlyDev accept {
        tvm.accept();
        addr.transfer(value, false, 3);
    }

    function upgrade() public offchain onlyDev {
        require(repo.exists(0));
        TvmCell newcode = repo[0].code;
        tvm.accept();
        tvm.commit();
        tvm.setcode(newcode);
        tvm.setCurrentCode(newcode);
        onCodeUpgrade(version + 1);
    }

    function onCodeUpgrade(uint16 v) internal {
        tvm.resetStorage();
        version = v;
    }
}
