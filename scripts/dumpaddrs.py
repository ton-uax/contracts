import sys
from pathlib import Path
from tonclient.types import *
from tonclient.client import MAINNET_BASE_URL, TonClient, DEVNET_BASE_URL


def ABI(dir_path, name):
    return Abi.from_path(dir_path / f'{name}.abi.json')

def create_client(url):
    config = ClientConfig()
    config.network.server_address = url
    return TonClient(config=config)


def get_account_boc(query):
    return TON.net.query_collection(
        ParamsOfQueryCollection('accounts', 'boc', query)
    ).result[0]['boc']


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


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise Exception('Need 1 arg: network [mainnet, devnet]')
    
    NET = sys.argv[1]

    if NET not in ['mainnet', 'devnet']:
        raise Exception('Possible network names: mainnet, devnet')

    BUILD_DIR = Path.cwd() / 'build'
    DATA_DIR = Path.cwd() / 'data'

    TON = create_client(DEVNET_BASE_URL if NET == 'devnet' else MAINNET_BASE_URL)

    repo_addr = (Path('data') / f'Repo.addr').read_text().strip()
    contracts = {
        'Console': '1',
        'EventLog': '2',
        'Medium': '4',
    }
    root_addr = run_getter(repo_addr, ABI(BUILD_DIR, 'Repo'), '_deployed')['_deployed']['3']
    system_addrs = run_getter(root_addr, ABI(BUILD_DIR, 'Root'), '_deployed')['_deployed']

    all_addrs = {}
    all_addrs['Repo'] = repo_addr
    all_addrs['Root'] = root_addr

    for name, i in contracts.items():
        addr = system_addrs.get(i)
        all_addrs[name] = addr
    
    for name, addr in all_addrs.items():
        print(name, addr)
        if addr:
            (Path('data') / f'{name}.addr').write_text(addr)
    
    (Path('data') / f'All.addr.json').write_text(json.dumps(all_addrs, indent=2))


