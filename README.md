# UAX Contracts

For better understanding of TON smart contract deployment pipeline, [read this short intro](Glossary.md). You can also get deeper understanding of technical details, see examples and examine specs [here](https://ton.dev).

Deploy instructions assume that you have installed:

- [TON Solidity Compiler](https://github.com/tonlabs/TON-Solidity-Compiler)
- [TVM Linker](https://github.com/tonlabs/TVM-linker)
- [TONOS SE - Local Node for testing](https://github.com/tonlabs/tonos-se)
- python 3.7+ and `pip install ton-client-py` (`requirements.txt` is also here)

## (For dev) Compile all contracts and deploy Repo

```bash
make clean
make compile
make predeploy net=main # net=dev|main|se
```

## (For operator) Deploy system

```bash
make deploy net=main
```

## User wallet deployment

```bash
make genusers net=main
```

## Dump contract addresses and keys for frontend

```bash
make dumpenv net=main
```

## Integrate with frontend MVP testbed

- Copy `data/Env.json` file to `src/uax` folder inside frontend repo.
- Build frontend bundle as usual
