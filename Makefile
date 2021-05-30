#########################################################################
# Compile and link
#########################################################################
BIN:=~/bin
SOLC:=$(BIN)/solc
LIB:=$(BIN)/stdlib_sol.tvm
LINKER:=$(BIN)/tvm_linker

CONTRACTS:=Repo Console EventLog Root Medium OwnerWallet TokenWallet
TVCS:=$(patsubst %, build/%.tvc,$(CONTRACTS))

compile: $(TVCS)
	echo $^

# recipe to compile and link
build/%.tvc: src/%.sol
	$(SOLC) $^ -o build
	$(LINKER) compile --lib $(LIB) build/$*.code -a build/$*.abi.json -o $@

#########################################################################
# Deploy
#########################################################################

deploydev:
	-python scripts/deploy.py devnet

deploymain:
	-python scripts/deploy.py mainnet


#########################################################################
# Deploy
#########################################################################

dumpaddrsdev:
	-python scripts/dumpaddrs.py devnet

dumpaddrsmain:
	-python scripts/dumpaddrs.py mainnet


#########################################################################
# Generate user wallet
#########################################################################

userdev:
	-python scripts/genwallet.py devnet

usermain:
	-python scripts/genwallet.py mainnet
