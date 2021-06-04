# UAX Contracts

This is UAX contracts repo.

Deploy instructions assume that you have TON Solidity Compiler and TVM Linker installed

## Compile all contracts

```bash
make compile
```

## Deploy system

```bash
make repo net=devnet
make deploy net=devnet # net=devnet|mainnet|se
```

## User wallet deployment

```bash
make genusers net=devnet
```

## Dump contract addresses and keys for frontend

```bash
make dumpenv net=devnet
```

## Integrate with frontend MVP testbed

- Copy `data/Env.json` file to `src/uax` folder inside frontend repo.
- Build frontend bundle as usual

