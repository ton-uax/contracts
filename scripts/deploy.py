import sys
from pathlib import Path

from tonclient.types import CallSet, DeploySet, KeyPair, Signer

from common import (
    BUILD_DIR, DATA_DIR, NETWORKS, ABI, TVC, AccountType, ZERO_ADDRESS,
    calc_address, create_client, hex2tons, make_keys, nanotons, query_account, run_onchain)


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
        input(f'Top up address of the contract ({to}) with {tons} TONs and preess <Enter>')
    elif NET == 'se':
        print('')
        giver_abi = ABI(DEPLOY_DATA_DIR, 'SEGiver')
        giver_address = (DEPLOY_DATA_DIR / 'SEGiver.addr').read_text().strip()
        call_set = CallSet(function_name='sendGrams', input={'dest': to, 'amount': nanotons(tons)})
        run_onchain(giver_address, giver_abi, call_set=call_set, wait=wait)
    else:
        giver_abi = ABI(DEPLOY_DATA_DIR, 'Giver')
        giver_address = (DEPLOY_DATA_DIR / 'Giver.addr').read_text().strip()
        call_set = CallSet(function_name='sendTo', input={'dest': to, 'val': tons})
        run_onchain(giver_address, giver_abi, call_set=call_set, wait=wait)


def deploy_root(repo_addr, repo_abi, pubkeys):
    print('Deploying Root contract...')
    call_set = CallSet(function_name='deployRoot', input={'ownerKeys': pubkeys})
    return run_onchain(repo_addr, repo_abi, call_set=call_set)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise Exception(f"Need 1 arg: network ({', '.join(NETWORKS.keys())})")

    NET = sys.argv[1]
    if NET not in NETWORKS.keys():
        raise Exception(f"Possible network names: {', '.join(NETWORKS.keys())}")

    create_client(NETWORKS[NET])

    OWNER_KEYS_DIR = DATA_DIR / 'keys'
    DEPLOY_DATA_DIR = DATA_DIR / 'giver'
    
    print('Generating owner keys')
    OWNER_KEYS_DIR.mkdir(parents=True, exist_ok=True)
    pubkeys = []
    for i in range(3):
        result = make_keys(f'Owner {i + 1}', OWNER_KEYS_DIR / f'o{i + 1}.keys.json')
        pubkeys.append('0x' + result['keypair'].public)
    print("\nGenerated owner public keys:")
    print('\n'.join(pubkeys), end='\n\n')

    abi, tvc = ABI(BUILD_DIR, 'Repo'), TVC(BUILD_DIR, 'Repo')
    repo = (DATA_DIR / 'Repo.addr').read_text().strip()

    result = deploy_root(repo, abi, pubkeys)
    print(result.decoded.output['rootAddr'])

