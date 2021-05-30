# UAX Contracts

This is UAX contracts repo.

Deploy instructions assume that you have TON Solidity Compiler and TVM Linker installed

## Deploy system

```bash
make compile
make deploydev # or deploymain
```

## Dump system contract addresses

```bash
make dumpaddrsdev # or dumpaddrsmain
```

## User wallet deployment

```bash
make userdev # or deploymain
```

## Integrate with frontend MVP testbed

- Copy `data/All.addr.json` file to `src/uax` folder inside frontend repo.

- Copy all files from `data/keys` directory to `src/uax/ton-keys` folder inside frontend repo
