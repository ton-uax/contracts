import sys
import json
from pathlib import Path
from pprint import pprint

from tonclient.types import ParamsOfGetCodeFromTvc

from common import (
    ABI, TVC, NETWORKS, DATA_DIR, BUILD_DIR, KeyPair, Signer, CallSet, DeploySet,
    calc_address, code_from_tvc, create_client, get_account_info, make_keys, nanotons, run_getter, run_onchain, deploy, get)


def give(to, tons, wait=True):
    if NET == 'mainnet':
        input(f'Top up address of the main contract ({to}) with {tons} TONs and preess <Enter>')
    elif NET == 'se':
        print(f'Sending {tons} to {to}')
        giver_abi = ABI(DEPLOY_DATA_DIR, 'SEGiver')
        giver_address = (DEPLOY_DATA_DIR / 'SEGiver.addr').read_text().strip()
        call_set = CallSet(function_name='sendGrams', input={'dest': to, 'amount': nanotons(tons)})
        run_onchain(giver_address, giver_abi, call_set=call_set, wait=wait)
    else:
        print(f'Sending {tons} to {to}')
        giver_abi = ABI(DEPLOY_DATA_DIR, 'Giver')
        giver_address = (DEPLOY_DATA_DIR / 'Giver.addr').read_text().strip()
        call_set = CallSet(function_name='sendTo', input={'dest': to, 'val': tons})
        run_onchain(giver_address, giver_abi, call_set=call_set, wait=wait)


def upgrade_repo(repo_addr, repo_abi, sign_keys):
    call_set = CallSet(
        function_name='uploadCode', 
        input={'index': 0, 'image': SYSTEM_IMAGES['0']})
    print('Uploading new Repo code')
    run_onchain(repo_addr, repo_abi, call_set=call_set, signer=Signer.Keys(sign_keys))
    print('Upgrading repo')
    call_set = CallSet(function_name='upgrade', input={})
    run_onchain(repo_addr, repo_abi, call_set=call_set, signer=Signer.Keys(sign_keys))


def upload_contract_images(repo_addr, repo_abi, sign_keys):
    images = run_getter(repo_addr, repo_abi, 'repo')['repo']
    for idx, image in SYSTEM_IMAGES.items():
        if idx in images and images[idx]['code'] == image['code']:
            continue
        print(f"uploading {bytes.fromhex(image['name']).decode('ascii')} image")
        call_set = CallSet(function_name='uploadCode', input={'index': idx, 'image': image})
        run_onchain(repo_addr, repo_abi, call_set=call_set, signer=Signer.Keys(sign_keys))


def setup(keys, abi, tvc, repo_addr):
    info = get_account_info(repo_addr)

    if not info['is_deployed']:
        pprint(info, indent=2)
        give(repo_addr, GIVER_VALUE, wait=True)

        print(f'Deploying {CONTRACT}')
        deploy(
            repo_addr, abi, tvc,
            sign_keys=keys,
            wait=True)
        (DATA_DIR / 'Repo.addr').write_text(repo_addr)

    info = get_account_info(repo_addr)
    print(repo_addr)
    pprint(info)

    upload_contract_images(repo_addr, abi, keys)


def deploy_root(repo_addr, repo_abi, sign_keys, pubkeys):
    print('Deploying Root...')
    call_set = CallSet(function_name='deployRoot', input={'ownerKeys': pubkeys})
    return run_onchain(repo_addr, repo_abi, call_set=call_set, signer=Signer.Keys(sign_keys))


def uax_deploy(repo_addr, repo_abi, sign_keys):
    pubkeys = []
    for i in range(3):
        kp = KeyPair.load(OWNER_KEYS_DIR / f'o{i + 1}.keys.json', False)
        pubkeys.append('0x' + kp.public)
    result = deploy_root(repo_addr, repo_abi, sign_keys, pubkeys)
    print(result.decoded.output['rootAddr'])


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print(f"Need 1 arg: network ({', '.join(NETWORKS.keys())})")
        exit()

    NET = sys.argv[1]
    if NET not in NETWORKS.keys():
        print(f"Possible network names: {', '.join(NETWORKS.keys())}")
        exit()

    create_client(NETWORKS[NET])

    OWNER_KEYS_DIR = DATA_DIR / 'keys'
    DEPLOY_DATA_DIR = DATA_DIR / 'giver'
    DEPLOY_KEY_PATH = OWNER_KEYS_DIR / 'deploy.keys.json'
    
    CONTRACT = 'Repo'
    GIVER_VALUE = 90

    SYSTEM_IMAGE_NAMES = {
        0: 'Repo',
        1: 'Root',
        2: 'Medium',
        3: 'TokenWallet',
        4: 'OwnerWallet',
    }
    SYSTEM_IMAGE_INIT_BALANCES = {
        0: 50,
        1: 20,
        2: 5,
        3: 1,
        4: 1,
    }

    SYSTEM_IMAGES = {
        f'{i}': {
            'code': code_from_tvc(TVC(BUILD_DIR, SYSTEM_IMAGE_NAMES[i])),
            'tons': SYSTEM_IMAGE_INIT_BALANCES[i],
            'name': bytes(SYSTEM_IMAGE_NAMES[i], 'ascii').hex(),
        } for i in [0, 1, 2, 3, 4]
    }

    if not DEPLOY_KEY_PATH.exists():
        print('Generating deploy keys')
        make_keys(path=DEPLOY_KEY_PATH, verbose=False)

    ENV = json.loads((Path.cwd() / 'data' / 'Env.json').read_text())

    keys = KeyPair.load(DEPLOY_KEY_PATH, False)
    abi, tvc = ABI(BUILD_DIR, CONTRACT), TVC(BUILD_DIR, CONTRACT)

    repo_addr = calc_address(abi, tvc, keys.public)
    if (DATA_DIR / 'Repo.addr').exists():
        repo_addr = (DATA_DIR / 'Repo.addr').read_text().strip()

    if len(sys.argv) > 2:
        cmd = sys.argv[2]
        if cmd == 'setup':
            setup(keys, abi, tvc, repo_addr)

        if cmd == 'upgrade':
            upgrade_repo(repo_addr, abi, keys)
            setup(keys, abi, tvc, repo_addr)

        if cmd == 'giver':
            addr = sys.argv[3]
            addr = ENV['contracts'].get(addr.capitalize(), addr)
            amount = sys.argv[4]
            give(addr, amount, wait=True)

        if cmd == 'deploy':
            uax_deploy(repo_addr, abi, keys)

        if cmd in ['repo', 'root', 'medium']:
            abi = ABI(BUILD_DIR, cmd.capitalize())
            address = ENV['contracts'][cmd.capitalize()]
            action = sys.argv[3]
            if action == 'get':
                getters = sys.argv[4:]
                for getter in getters:
                    pprint(get(address, abi, getter))

