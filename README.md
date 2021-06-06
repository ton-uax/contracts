# UAX Contracts

This is UAX contracts repo.

Deploy instructions assume that you have installed:
- TON OS SE (Local Node for testing) 
- TON Solidity Compiler 
- TVM Linker


## Compile all contracts

```bash
make clean
make compile
```

## Deploy system

```bash
make predeploy net=dev
make deploy net=dev # net=dev|main|se
```

## User wallet deployment

```bash
make genusers net=dev
```

## Dump contract addresses and keys for frontend

```bash
make dumpenv net=dev
```

## Integrate with frontend MVP testbed

- Copy `data/Env.json` file to `src/uax` folder inside frontend repo.
- Build frontend bundle as usual

