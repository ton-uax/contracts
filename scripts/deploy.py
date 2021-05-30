import sys
from time import sleep
from pprint import pprint
from enum import IntEnum
from pathlib import Path
from base64 import b64encode

from tonclient.types import *
from tonclient.client import MAINNET_BASE_URL, TonClient, DEVNET_BASE_URL


class AccountType(IntEnum):
    UNINIT = 0
    ACTIVE = 1
    FROZEN = 2
    NOTEXIST = 3


def hex2dec(n):
    return int(n, 16)


def tons(nanotons):
    return nanotons / 10 ** 9


def hex2tons(n):
    return tons(hex2dec(n))


def ABI(dir_path, name):
    return Abi.from_path(dir_path / f'{name}.abi.json')


def TVC(dir_path, name):
    path = (dir_path / f'{name}.tvc')
    return b64encode(path.read_bytes()).decode()


def create_client(url):
    config = ClientConfig()
    config.network.server_address = url
    return TonClient(config=config)


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


def make_keys(keyname, path, phrase=None):
    if not phrase:
        phrase = TON.crypto.mnemonic_from_random(ParamsOfMnemonicFromRandom()).phrase
    input(f"Will display phrase for '{keyname}' keys now. Press <Enter> to continue")
    print(f'Your phrase ({keyname}): {phrase}')
    kp = TON.crypto.mnemonic_derive_sign_keys(ParamsOfMnemonicDeriveSignKeys(phrase))
    if path:
        kp.dump(path, as_binary=False)
        print(f"Keypair saved at {path}")
    else:
        print(f'Public Key: {kp.public}')
        print(f'Secret Key: {kp.secret}')
    return {'phrase': phrase, 'keypair': kp}


def make_account(tvc, abi, pubkey, init_data=None):
    init_data = init_data or {}
    src = StateInitSource.Tvc(tvc, pubkey, StateInitParams(abi, {}))
    account = TON.abi.encode_account(ParamsOfEncodeAccount(src, 0, 0, 0))
    return account


def calc_address(abi, tvc, pubkey, init_data=None, wc=0):
    acc = make_account(tvc, abi, pubkey, init_data)
    return f'{wc}:{acc.id}'


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


def is_deployed(address):
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
    return is_deployed, balance, state


def give(to, tons, wait=True):
    if NET == 'mainnet':
        input(f'Top up address of the main contract ({to}) with {tons} TONs and preess <Enter>')
    else:
        giver_abi = ABI(DEPLOY_DATA_DIR, 'Giver')
        giver_address = (DEPLOY_DATA_DIR / 'Giver.addr').read_text().strip()
        call_set = CallSet(function_name='sendTo', input={'dest': to, 'val': tons})
        run_onchain(giver_address, giver_abi, call_set=call_set, wait=wait)


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


def set_owners(repo_addr, repo_abi, pubkeys):
    call_set = CallSet(function_name='setOwnerKeys', input={'keys': pubkeys})
    return run_onchain(repo_addr, repo_abi, call_set=call_set)


def upload_contract_images(repo_addr, repo_abi):
    for idx, image in SYSTEM_IMAGES.items():
        print(f"uploading {bytes.fromhex(image['name']).decode('ascii')} image")
        call_set = CallSet(function_name='updateImage', input={'index': idx, 'image': image})
        run_onchain(repo_addr, repo_abi, call_set=call_set)


def deploy_all(repo_addr, repo_abi):
    print('Deploying system contracts...')
    call_set = CallSet(function_name='deploy', input={})
    return run_onchain(repo_addr, repo_abi, call_set=call_set)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise Exception('Need 1 arg: network [mainnet, devnet]')

    NET = sys.argv[1]

    if NET not in ['mainnet', 'devnet']:
        raise Exception('Possible network names: mainnet, devnet')

    OWNER_KEYS_DIR = Path.cwd() / 'data' / 'keys'
    OWS_CFG_PATH = Path.cwd() / 'data' / 'Owners.pubkeys.json'
    DEPLOY_DATA_DIR = Path.cwd() / 'data' / 'giver'
    DEPLOY_KEY_PATH = DEPLOY_DATA_DIR / 'deploy.keys'
    BUILD_DIR = Path.cwd() / 'build'

    CONTRACT = 'Repo'
    GIVER_VALUE = 200
    CTOR_PARAMS = {}

    SYSTEM_IMAGE_NAMES = {
        1: 'Console',
        2: 'EventLog',
        3: 'Root',
        4: 'Medium',
        6: 'TokenWallet',
        7: 'OwnerWallet'
    }
    SYSTEM_IMAGE_INITVALUES = {
        1: 8,
        2: 6,
        3: 97,
        4: 15,
        6: 5,
        7: 2
    }
    SYSTEM_IMAGES = {
        i: {
            'name': bytes(SYSTEM_IMAGE_NAMES[i], 'ascii').hex(),
            'initialBalance': SYSTEM_IMAGE_INITVALUES[i],
            'si': TVC(BUILD_DIR, SYSTEM_IMAGE_NAMES[i])
        } for i in [1, 2, 3, 4, 6, 7]
    }

    TON = create_client(DEVNET_BASE_URL if NET == 'devnet' else MAINNET_BASE_URL)

    deploy_keys = make_keys('deploy', DEPLOY_KEY_PATH)

    print('Generating owner keys')
    pubkeys = []
    for i in range(3):
        result = make_keys(f'Owner {i + 1}', OWNER_KEYS_DIR / f'o{i + 1}.keys.json')
        pubkeys.append('0x' + result['keypair'].public)
    pubkeys_dump = json.dumps(pubkeys, separators=(',', ':'))
    print(f'Generated owner public keys:\n {pubkeys_dump}')
    with OWS_CFG_PATH.open('w') as f:
        f.write(pubkeys_dump)
    
    print(f'Generating user keys')
    for i in range(2):
        make_keys(f'User {i + 1}', OWNER_KEYS_DIR / f'u{i + 1}.keys.json')

    keys = KeyPair.load(DEPLOY_KEY_PATH, False)
    abi, tvc = ABI(BUILD_DIR, CONTRACT), TVC(BUILD_DIR, CONTRACT)

    address = calc_address(abi, tvc, keys.public)
    deployed, explain, balance = is_deployed(address)

    print(f'{address} {balance} {explain}')
    if not deployed:
        print(f'sendTo {address} {GIVER_VALUE} TON and deploy?')
        input()
        give(address, GIVER_VALUE, wait=False)

        print(f'Deploying {CONTRACT} {CTOR_PARAMS}')
        result = deploy(
            address, abi, tvc,
            ctor_params=CTOR_PARAMS,
            sign_keys=keys,
            wait=True)
        print(f'txid {result.transaction["id"]}')
        
        deployed, explain, balance = is_deployed(address)
        print(f'{address} {balance} {explain}')
    

    print('Setting up owner pubkeys')
    set_owners(address, abi, pubkeys)
    upload_contract_images(address, abi)
    deploy_all(address, abi)

    (Path('data') / f'{CONTRACT}.addr').write_text(address)
