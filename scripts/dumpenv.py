import sys
import json

from common import ABI, TVC, BUILD_DIR, DATA_DIR, NETWORKS, KeyPair, create_client, run_getter, calc_address


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
    keys = KeyPair.load(DEPLOY_KEY_PATH, False)
    
    repo_addr = calc_address(ABI(BUILD_DIR, 'Repo'), TVC(BUILD_DIR, 'Repo'), keys.public)
    root_addr = run_getter(repo_addr, ABI(BUILD_DIR, 'Repo'), 'deployed')['deployed']['1']
    medium_addr = run_getter(root_addr, ABI(BUILD_DIR, 'Root'), '_medium')['_medium']

    all_addrs = {
        'Repo': repo_addr,
        'Root': root_addr,
        'Medium': medium_addr
    }

    owners = []
    for i in range(3):
        kp = KeyPair.load(OWNER_KEYS_DIR / f"o{i + 1}.keys.json", False)
        owners.append({
            "keys": kp.dict,
            "addr": calc_address(ABI(BUILD_DIR, 'OwnerWallet'), TVC(BUILD_DIR, 'OwnerWallet'), kp.public),
            "wallet": calc_address(ABI(BUILD_DIR, 'TokenWallet'), TVC(BUILD_DIR, 'TokenWallet'), kp.public)
        })
    
    users = []
    for i in range(2):
        kp = KeyPair.load(OWNER_KEYS_DIR / f"u{i + 1}.keys.json", False)
        users.append({
            "keys": kp.dict,
            "addr": calc_address(ABI(BUILD_DIR, 'TokenWallet'), TVC(BUILD_DIR, 'TokenWallet'), kp.public)
        })

    env = {
        "contracts": all_addrs,
        "owners": owners,
        "users": users
    }
    
    (DATA_DIR / f'Env.json').write_text(json.dumps(env, indent=2))



