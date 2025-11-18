-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil scopefile

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

CONTRACT_NAME=PureWalletV5

all: remove install build build-circom-zkp

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm --force .git/index.lock && rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules" 

# install dependencies, for the latest compiler and circom-zkp submodule
install:
	forge install foundry-rs/forge-std\
		&& forge i OpenZeppelin/openzeppelin-contracts 

build-circom-zkp:
	cd lib/circom-zkp && npm install && make all

# Obtain ABI in json
abi :
	forge inspect src/$(CONTRACT_NAME).sol:$(CONTRACT_NAME) abi > $(CONTRACT_NAME).json 
	jq '.abi' out/$(CONTRACT_NAME).sol/$(CONTRACT_NAME).json  > abi$(CONTRACT_NAME).json
	rm $(CONTRACT_NAME).json 
	@echo "ABI for $(CONTRACT_NAME) contract generated in abi$(CONTRACT_NAME).json"

# Update Dependencies
update:; forge update

# build:; forge build

build:; forge build --ignored-error-codes 3860 --ignored-error-codes 2072 --via-ir

test :; forge test --fork-url $(RPC_ETH) --fork-block-number 22865007 --via-ir --ffi --ignored-error-codes 3860

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# slither is only in venv, hance make sure to run `source .venv/bin/activate`
slither :; slither ./src/DriverDapp.sol --config-file slither.config.json --checklist > docs/slither-report.md

scope :; tree ./src/ | sed 's/└/#/g; s/──/--/g; s/├/#/g; s/│ /|/g; s/│/|/g'

scopefile :; @tree ./src/ | sed 's/└/#/g' | awk -F '── ' '!/\.sol$$/ { path[int((length($$0) - length($$2))/2)] = $$2; next } { p = "src"; for(i=2; i<=int((length($$0) - length($$2))/2); i++) if (path[i] != "") p = p "/" path[i]; print p "/" $$2; }' > scope.txt

aderyn :; aderyn . -o ./docs/aderyn-report.md -x test,script,interfaces

coverage :; forge coverage --rpc-url $(RPC_ETH) --report lcov && genhtml lcov.info -o report --branch-coverage --via-ir

# -----Pure Wallet----- #
# Deploy PW contract
deploy-mainnet :; forge script script/PureWallet.s.sol:DeployPureWalletScript --rpc-url $(RPC_ETH) --broadcast -vvvv

deploy-fork :; forge script script/PureWallet.s.sol:DeployPureWalletScript --rpc-url $(RPC_FORK) --broadcast -vvvv

deploy-sepolia :; forge script script/PureWallet.s.sol:DeployPureWalletTestnetScript --rpc-url $(RPC_ETH_SEPOLIA) --broadcast -vvvv

deploy-holesky :; forge script script/PureWallet.s.sol:DeployPureWalletTestnetScript --rpc-url $(RPC_ETH_HOLESKY) --broadcast -vvvv
