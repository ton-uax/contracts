pragma ton-solidity >= 0.36.0;
import "Types.sol";
import "Root.sol";
import "IRepo.sol";


contract Repo is IRepo {

    modifier accept {
        tvm.accept();
        _;
    }

    uint16 constant ROOT_ID     = 30;
    uint64 constant REIMBURSE   = 3e8;

    uint[] public _ownerKeys;
    mapping (uint8 => CTImage) public _images;
    mapping (uint8 => address) public _deployed;

    function deploy() external accept {
        CTImage image = _images[3];
        TvmCell signed = tvm.insertPubkey(image.si, tvm.pubkey());
        uint128 val = uint128(image.initialBalance) * 1e9;
        new Root {stateInit: signed, value: val}();
    }

    function onDeploy(uint16 id) external override accept {
        if (id == ROOT_ID) {
            address from = msg.sender;
            _deployed[3] = from;
            Root(from).updateSystemImage{value: REIMBURSE}(_images[1], _images[2], _images[3], _images[4]);
            Root(from).updateUserImage{value: REIMBURSE}(_images[6], _images[7], _ownerKeys); // 6 = OwnerWallet, 7 = TokenWallet
        }
    }

    function updateImage(uint8 index, CTImage image) external accept {
        _images[index] = image;
    }

    function setOwnerKeys(uint[] keys) external accept {
        _ownerKeys = keys;
    }

    function upgrade(TvmCell c) external {
//        require(msg.pubkey() == tvm.pubkey(), 100);
        TvmCell newcode = c.toSlice().loadRef();
        tvm.accept();
        tvm.commit();
        tvm.setcode(newcode);
        tvm.setCurrentCode(newcode);
        onCodeUpgrade();
    }

    function onCodeUpgrade() internal {
        tvm.resetStorage();
    }
}
