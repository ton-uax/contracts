import sys
import json

from common import ABI, TVC, BUILD_DIR, DATA_DIR, NETWORKS, KeyPair, create_client, calc_address, get


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
    if (DATA_DIR / 'Repo.addr').exists():
        repo_addr = (DATA_DIR / 'Repo.addr').read_text().strip()

    print('Repo', repo_addr)
    root_addr = get(repo_addr, ABI(BUILD_DIR, 'Repo'), 'deployed')['1']
    print('Root', root_addr)
    medium_addr = get(root_addr, ABI(BUILD_DIR, 'Root'), '_medium')
    print('Medium', medium_addr)

    print('Writing full env for webapp...')

    all_addrs = {
        'Repo': repo_addr,
        'Root': root_addr,
        'Medium': medium_addr
    }

    owners_data = get(medium_addr, ABI(BUILD_DIR, 'Medium'), '_owners')
    owners = []
    for i in range(3):
        owner = owners_data[str(i)]

        kp = KeyPair.load(OWNER_KEYS_DIR / f"o{i + 1}.keys.json", False)
        owners.append({
            "keys": kp.dict,
            "addr": owner['addr'],
            "wallet": owner['tokenWalletAddr']
        })
    
    users = []
    pubkey2addr = {
        user['key']: addr 
        for addr, user in get(root_addr, ABI(BUILD_DIR, 'Root'), '_roster').items()
    }

    for i in range(2):
        kp = KeyPair.load(OWNER_KEYS_DIR / f"u{i + 1}.keys.json", False)
        users.append({
            "keys": kp.dict,
            "addr": pubkey2addr['0x' + kp.public]
        })

    env = {
        "contracts": all_addrs,
        "owners": owners,
        "users": users,
        "network": NET
    }
    
    (DATA_DIR / f'Env.json').write_text(json.dumps(env, indent=2))



