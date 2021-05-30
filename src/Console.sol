pragma ton-solidity >= 0.36.0;
import "Base.sol";
import "IConsole.sol";
import "IEventLog.sol";
import "IRoot.sol";
import "IMedium.sol";
import "ITokenWallet.sol";
import "IOwnerWallet.sol";

/* Administrative console */
contract Console is Base, IConsole {

    address _repo;

    constructor() public accept {
    	_repo = msg.sender;
        IRoot(_repo).onDeploy{value: REIMBURSE}(CONSOLE_ID);
    }

    function initConsole(address eventLog, address root, address medium, uint16 logLevel) external accept override {

        _id = CONSOLE_ID;
        address console = address(this);
        _setEnv(console, eventLog, root, medium, logLevel);

        Base(eventLog).initMember{value: COMPUTE}(EVENT_LOG_ID, console, eventLog, root, medium, logLevel);
        Base(root).initMember{value: COMPUTE}(ROOT_ID, console, eventLog, root, medium, logLevel);
        Base(medium).initMember{value: COMPUTE}(MEDIUM_ID, console, eventLog, root, medium, logLevel);
    }

    /* Token Wallet deployment interface */

    function deployTokenWallets(uint16 n) external view accept {
        IRoot(_root).deployTokenWallets{value: REIMBURSE}(n);
    }

    function deployTokenWalletsWithKeys(uint[] keys) external view accept {
        IRoot(_root).deployTokenWalletsWithKeys{value: REIMBURSE}(keys);
    }

    function deployOwners() external view accept {
        IRoot(_root).deployOwners{value: REIMBURSE}();
    }

    function doTransfer(address from, address to, uint32 val) external pure accept {
        ITokenWallet(from).transferTokens{value: PROCESS}(to, val);
    }

    function setRefillOptions(uint64 initialBalance, uint64 warnBalance, uint64 refillValue, uint32 updateTimeout) external view accept {
        IRoot(_root).updateRefillConfig{value: PROCESS}(initialBalance, warnBalance, refillValue, updateTimeout);
    }

    function setEnv2(address console, address eventLog, address root, address medium, uint16 logLevel) external view accept {
        IRoot(_root).setEnv{value: COMPUTE}(console, eventLog, root, medium, logLevel);
    }

    function updateWalletsEnv() external view accept {
        IRoot(_root).updateWalletsEnv{value: COMPUTE}();
    }

    function updateSystemEnv() external view accept {
        IRoot(_root).updateSystemEnv{value: COMPUTE}();
    }

    function registerOwners() external view accept {
        IRoot(_root).registerOwners{value: COMPUTE}();
    }

    function setEnv(address console, address eventLog, address root, address medium, uint16 logLevel) external accept {
        _setEnv(console, eventLog, root, medium, logLevel);
        Base(console).updateEnv{value: COMPUTE}(console, eventLog, root, medium, logLevel);
        Base(eventLog).updateEnv{value: COMPUTE}(console, eventLog, root, medium, logLevel);
        Base(root).updateEnv{value: COMPUTE}(console, eventLog, root, medium, logLevel);
        Base(medium).updateEnv{value: COMPUTE}(console, eventLog, root, medium, logLevel);
        IRoot(root).updateWalletsEnv{value: REIMBURSE}();
    }

    function shuffle() external view accept {
        IRoot(_root).onDeploy{value: COMPUTE}(CONSOLE_ID);
    }

    function approve(address addr, uint32 eventID) external pure accept {
        IOwnerWallet(addr).approve{value: PROCESS}(eventID);
    }

    function reject(address addr, uint32 eventID) external pure accept {
        IOwnerWallet(addr).reject{value: PROCESS}(eventID);
    }

    function propose(address addr, EventType eType, uint32 value) external pure accept {
        IOwnerWallet(addr).propose{value: PROCESS}(eType, value);
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
