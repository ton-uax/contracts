import sys
from pprint import pprint
from pathlib import Path
from base64 import b64encode
from tonclient.types import *
from tonclient.client import MAINNET_BASE_URL, TonClient, DEVNET_BASE_URL


def ABI(dir_path, name):
    return Abi.from_path(dir_path / f'{name}.abi.json')


def TVC(dir_path, name):
    path = (dir_path / f'{name}.tvc')
    return b64encode(path.read_bytes()).decode()


def create_client(url):
    config = ClientConfig()
    config.network.server_address = url
    return TonClient(config=config)


def make_account(tvc, abi, pubkey, init_data=None):
    init_data = init_data or {}
    src = StateInitSource.Tvc(tvc, pubkey, StateInitParams(abi, {}))
    account = TON.abi.encode_account(ParamsOfEncodeAccount(src, 0, 0, 0))
    return account


def calc_address(abi, tvc, pubkey, init_data=None, wc=0):
    acc = make_account(tvc, abi, pubkey, init_data)
    return f'{wc}:{acc.id}'


def make_keys(keyname, path=None, phrase=None):
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


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise Exception('Need 1 arg: network [mainnet, devnet]')
    
    NET = sys.argv[1]

    if NET not in ['mainnet', 'devnet']:
        raise Exception('Possible network names: mainnet, devnet')

    BUILD_DIR = Path.cwd() / 'build'
    DATA_DIR = Path.cwd() / 'data'

    TON = create_client(DEVNET_BASE_URL if NET == 'devnet' else MAINNET_BASE_URL)

    root_addr = (Path('data') / f'Root.addr').read_text().strip()
    keys = make_keys('User')

    run_onchain(
        root_addr, ABI(BUILD_DIR, 'Root'), 
        call_set=CallSet(
            function_name='deployTokenWalletsWithKeys', 
            input={'keys': [f"0x{keys['keypair'].public}"]}
        ))
    address = calc_address(ABI(BUILD_DIR, 'TokenWallet'), TVC(BUILD_DIR, 'TokenWallet'), keys['keypair'].public)
    print(f'Generated new UAX Token Wallet: {address}')
