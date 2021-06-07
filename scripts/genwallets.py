import sys

from tonclient.types import CallSet, KeyPair

from common import (
    BUILD_DIR, DATA_DIR, NETWORKS, ABI, TVC, 
    calc_address, create_client, make_keys, run_getter, run_onchain)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Need 1 arg: network ({', '.join(NETWORKS.keys())})")
        exit()

    NET = sys.argv[1]
    if NET not in NETWORKS.keys():
        print(f"Possible network names: {', '.join(NETWORKS.keys())}")
        exit()

    create_client(NETWORKS[NET])

    # DEPLOY_DATA_DIR = DATA_DIR / 'giver'
    # DEPLOY_KEY_PATH = DEPLOY_DATA_DIR / 'deploy.keys.json'
    # keys = KeyPair.load(DEPLOY_KEY_PATH, False)
    # repo_addr = calc_address(ABI(BUILD_DIR, 'Repo'), TVC(BUILD_DIR, 'Repo'), keys.public)
    
    repo_addr = (DATA_DIR / 'Repo.addr').read_text().strip()
    root_addr = run_getter(repo_addr, ABI(BUILD_DIR, 'Repo'), 'deployed')['deployed']['1']

    keys1 = make_keys('User 1', DATA_DIR / 'keys' / 'u1.keys.json')['keypair']
    keys2 = make_keys('User 2', DATA_DIR / 'keys' / 'u2.keys.json')['keypair']

    response = run_onchain(
        root_addr, ABI(BUILD_DIR, 'Root'), 
        call_set=CallSet(
            function_name='deployTokenWalletsWithKeys', 
            input={'keys': [f"0x{keys1.public}", f"0x{keys2.public}"]}
        ))

    print(f'Generated new UAX Token Wallets: {response.decoded.output["addrs"]}')
