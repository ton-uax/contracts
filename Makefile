BIN:=~/bin
SOLC:=$(BIN)/solc
LIB:=$(BIN)/stdlib_sol.tvm
LINKER:=$(BIN)/tvm_linker

clean:
	rm -rf build/*

#########################################################################
# Compile and link
#########################################################################

CONTRACTS:=Repo Root Medium OwnerWallet TokenWallet
TVCS:=$(patsubst %, build/%.tvc,$(CONTRACTS))

compile: $(TVCS)
	echo $^
	rm -rf build/*.code

# recipe to compile and link
build/%.tvc: src/%.sol
	$(SOLC) $^ -o build
	$(LINKER) compile --lib $(LIB) build/$*.code -a build/$*.abi.json -o $@


#########################################################################
# Deploy
#########################################################################

predeploy:
	-python scripts/uax.py $(net) setup

deploy:
	-python scripts/deploy.py $(net)


#########################################################################
# Generate user wallets
#########################################################################

genusers:
	-python scripts/genwallets.py $(net)


#########################################################################
# Dump system contracts addresses
#########################################################################

dumpenv:
	-python scripts/dumpenv.py $(net)
