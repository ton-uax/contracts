pragma ton-solidity >= 0.44.0;
pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;
import "ITokenWallet.sol";
import "IMedium.sol";
import "Base.sol";


contract TokenWallet is Base, ITokenWallet {

    uint32 _balance;
    uint32 _accountsPayable;
    uint32 _accountsReceivable;
    uint32 _actualBalance;

    modifier checkOwnerAndAmount(uint32 val) {
        require(msg.pubkey() == tvm.pubkey(), REQUIRES_OWNER_SIGNATURE); // 119 Requires owner's signature to operate
        require(val + _transferFee < _balance, INSUFFICIENT_BALANCE); // 215 Not enough funds to perform transfer
        tvm.accept();
        _;
        _checkTonBalance();
    }

    modifier trade {
        require(msg.sender == _medium, ILLEGAL_TRANSFER_ATTEMPT);
        _;
    }

    modifier accept {
        tvm.accept();
        _;
    }

    constructor(uint16 id, address medium) public accept {
        _id = id;
        _root = msg.sender;
        _medium = medium;
        IMedium(_medium).registerTokenWallet{value: PROCESS}(id);
    }

    function collect(uint32 val) external override trade {
        _accountsPayable -= val;
        _actualBalance -= val;
    }

    function incur(uint32 val) external override {
        _accountsReceivable += val;
        _balance += val;
    }

    function abort(uint32 val) external override trade {
        _accountsPayable -= val;
        _balance += val;
    }

    function withdraw(uint32 val) external override trade {
        _accountsReceivable -= val;
        _balance -= val;
    }

    function pay(uint32 val) external override trade {
        _accountsReceivable -= val;
        _actualBalance += val;
    }

    function debit(uint32 val) external override trade {
        if (val > _actualBalance) {
            // 216 Not enough funds to complete transfer
            _actualBalance = 0;
        } else {
            _actualBalance -= val;
            _balance -= val;
        }
    }

    function credit(uint32 val) external override trade {
        _actualBalance += val;
        _balance += val;
    }

    function donate(uint32 val) external view override checkOwnerAndAmount(val) {
        IMedium(_medium).accrue{value: PROCESS}(val);
    }

    function transferTokens(address to, uint32 val) external view override checkOwnerAndAmount(val) {
        IMedium(_medium).requestTransfer{value: PROCESS}(to, val);
    }

    function _accrueExpenses(uint32 val) private {
        uint32 total = val + _transferFee;
        _accountsPayable += total;
        _balance -= total;
    }

    function instantTransfer(address to, uint32 val) external override checkOwnerAndAmount(val) {
        _accrueExpenses(val);
        ITokenWallet(to).incur{value: PROCESS}(val);
        IMedium(_medium).processTransfer{value: PROCESS}(to, val);
    }

    function getFinances() external view returns (uint32 id, uint32 balance, uint32 accountsPayable, uint32 accountsReceivable, uint32 actualBalance) {
        id = _id;
        balance = _balance;
        accountsPayable = _accountsPayable;
        accountsReceivable = _accountsReceivable;
        actualBalance = _actualBalance;
    }
}
