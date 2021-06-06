from pathlib import Path
from pprint import pprint
from enum import IntEnum
from base64 import b64encode

from tonclient.types import *
from tonclient.client import TonClient, MAINNET_BASE_URL, DEVNET_BASE_URL


class AccountType(IntEnum):
    UNINIT = 0
    ACTIVE = 1
    FROZEN = 2
    NOTEXIST = 3


def hex2dec(n):
    return int(n, 16)


def tons(nanotons):
    return nanotons / 10 ** 9


def nanotons(tons):
    return tons * 10 ** 9


def hex2tons(n):
    return tons(hex2dec(n))


def ABI(dir_path, name):
    return Abi.from_path(dir_path / f'{name}.abi.json')


def TVC(dir_path, name):
    path = (dir_path / f'{name}.tvc')
    return b64encode(path.read_bytes()).decode()


def create_client(url):
    global TON
    config = ClientConfig()
    config.network.server_address = url
    TON = TonClient(config=config)


def query_account(query, fields: Union[str, List[str]]):
    if isinstance(fields, List):
        fields = ','.join(fields)
    single_field = False
    if ',' not in fields:
        single_field = True
    result = TON.net.query_collection(ParamsOfQueryCollection(
        'accounts', fields, query)).result
    if not result:
        return
    ret = result[0]
    if single_field:
        ret = ret[fields]
    return ret


def get_account_boc(query):
    return TON.net.query_collection(
        ParamsOfQueryCollection('accounts', 'boc', query)
    ).result[0]['boc']


def make_keys(keyname=None, path=None, phrase=None, verbose=True):
    def _print(*args):
        verbose and print(*args)

    if not phrase:
        phrase = TON.crypto.mnemonic_from_random(ParamsOfMnemonicFromRandom()).phrase
    
    if keyname:
        verbose and input(f"Will display phrase for '{keyname}' keys now. Press <Enter> to continue")
        _print(f'Your phrase ({keyname}): {phrase}')
    
    kp = TON.crypto.mnemonic_derive_sign_keys(ParamsOfMnemonicDeriveSignKeys(phrase))
    
    if path:
        kp.dump(path, as_binary=False)
        _print(f"Keypair saved at {path}")
    else:
        _print(f'Public Key: {kp.public}')
        _print(f'Secret Key: {kp.secret}')
    return {'phrase': phrase, 'keypair': kp}


def make_account(tvc, abi, pubkey, init_data=None):
    init_data = init_data or {}
    src = StateInitSource.Tvc(tvc, pubkey, StateInitParams(abi, {}))
    account = TON.abi.encode_account(ParamsOfEncodeAccount(src, 0, 0, 0))
    return account


def calc_address(abi, tvc, pubkey, init_data=None, wc=0):
    acc = make_account(tvc, abi, pubkey, init_data)
    return f'{wc}:{acc.id}'


def code_from_tvc(tvc):
    return TON.boc.get_code_from_tvc(ParamsOfGetCodeFromTvc(tvc)).code


def run_getter(address, abi, getter, params=None):
    params = params or {}
    msg = TON.abi.encode_message(
        params=ParamsOfEncodeMessage(
            abi=abi, signer=Signer.NoSigner(), address=address,
            call_set=CallSet(function_name=getter, input=params)))
    boc = get_account_boc({'id': {'eq': address}})
    response = TON.tvm.run_tvm(
        params=ParamsOfRunTvm(
            message=msg.message, abi=abi, account=boc)).decoded.output
    return response


def read_public(address, abi, getter):
    return run_getter(address, abi, getter)[getter]


def track_msg_onchain_execution(msg_or_params, shard_block_id, abi, tracker_cb):
    if isinstance(msg_or_params, ParamsOfEncodeMessage):
        msg = TON.abi.encode_message(msg_or_params)
    else:
        msg = msg_or_params

    return TON.processing.wait_for_transaction(ParamsOfWaitForTransaction(msg.message, shard_block_id, True, abi), tracker_cb)


def send_onchain(msg_params, abi, tracker_cb=None):
    msg = TON.abi.encode_message(msg_params)
    shard_block_id = TON.processing.send_message(
        ParamsOfSendMessage(msg.message, bool(tracker_cb), abi), tracker_cb).shard_block_id
    return msg, shard_block_id


def run_onchain(address, abi, call_set=None, deploy_set=None, signer=Signer.NoSigner(), wait=True):
    def cb(event, code, err):
        # print(event)
        if code != 100 or err is not None:
            pprint(code)
            pprint(err)

    msg_params = ParamsOfEncodeMessage(
        abi=abi, signer=signer, address=address,
        call_set=call_set, deploy_set=deploy_set)
    msg, shard_block_id = send_onchain(msg_params, abi, cb)
    if wait:
        return track_msg_onchain_execution(msg, shard_block_id, abi, cb)
    else:
        return msg, shard_block_id


def get_account_info(address):
    account_info = query_account({'id': {'eq': address}}, 'balance,acc_type')
    acc_type = account_info['acc_type'] if account_info else AccountType.NOTEXIST
    balance = hex2tons(
        account_info['balance']) if acc_type != AccountType.NOTEXIST else 0

    acc_type_deployed = {
        AccountType.ACTIVE: True,
        AccountType.FROZEN: True,
        AccountType.UNINIT: False,
        AccountType.NOTEXIST: False
    }
    acc_type_str = {
        AccountType.ACTIVE: 'active',
        AccountType.FROZEN: 'frozen',
        AccountType.UNINIT: 'uninit',
        AccountType.NOTEXIST: 'empty'
    }
    is_deployed = acc_type_deployed[acc_type]
    state = acc_type_str[acc_type]
    return {
        'is_deployed': is_deployed, 
        'balance': balance, 
        'state': state
    }


def deploy(
        to, abi, tvc, wc=0, init_data=None,
        ctor_params=None, deploy_pubkey=None, sign_keys=Signer.NoSigner, wait=True):
    ctor_params = ctor_params or {}
    
    deploy_set = DeploySet(
        tvc, workchain_id=wc, initial_data=init_data, initial_pubkey=deploy_pubkey)
    call_set = CallSet(function_name='constructor', input=ctor_params)
    return run_onchain(
        to, abi, call_set=call_set, deploy_set=deploy_set,
        signer=Signer.Keys(sign_keys), wait=wait)


ZERO_ADDRESS = "0:0000000000000000000000000000000000000000000000000000000000000000"
BUILD_DIR = Path.cwd() / 'build'
DATA_DIR = Path.cwd() / 'data'


NETWORKS = {
    'mainnet': MAINNET_BASE_URL,
    'devnet': DEVNET_BASE_URL,
    'se': 'http://localhost'
}

TON = None
