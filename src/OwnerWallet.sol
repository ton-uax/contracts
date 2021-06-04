pragma ton-solidity >= 0.41.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "Base.sol";
import "IOwnerWallet.sol";
import "IMedium.sol";

contract OwnerWallet is Base, IOwnerWallet {

    address _tokenWalletAddress;
    mapping (uint32 => EventState) public _events;

    modifier owner {
        require(msg.pubkey() == tvm.pubkey(), REQUIRES_OWNER_SIGNATURE);  // 119 Requires owner's signature to operate
        tvm.accept();
        _;
    }

    modifier accept {
        tvm.accept();
        _;
    }

    constructor(uint16 id, address medium, uint16 walletId, address walletAddress) public accept {
        _id = id;
        _root = msg.sender;
        _medium = medium;
        _tokenWalletAddress = walletAddress;
        IMedium(_medium).registerOwner{value: PROCESS}(id, walletId, walletAddress);
    }

    /* Collective Decision making */

    function approve(uint32 id) external override owner {
        IMedium(_medium).approve{value: PROCESS}(id);
    }

    function reject(uint32 id) external override owner {
        IMedium(_medium).reject{value: PROCESS}(id);
    }

    function propose(EventType eType, uint32 value) external override owner {
        IMedium(_medium).propose{value: PROCESS}(eType, value);
    }

    function updateEventState(uint32 id, EventState state) external override {
        require(msg.sender == _medium);
        _events[id] = state;
    }

    function getInfo() external view returns (uint16 id, uint pubkey, address tokenWalletAddress) {
        id = _id;
        pubkey = tvm.pubkey();
        tokenWalletAddress = _tokenWalletAddress;
    }
}
