-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil scopefile

DEFAULT_ANVIL_KEY := 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6

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
slither :; slither ./src --config-file slither.config.json --checklist > docs/slither-report.md

# Analyze specific contracts with slither
slither-access-registry :; slither ./src/AccessRegistry.sol --config-file slither.config.json --checklist > docs/slither-access-registry-report.md

slither-distraction-recorder :; slither ./src/DistractionRecorder.sol --config-file slither.config.json --checklist > docs/slither-distraction-recorder-report.md

scope :; tree ./src/ | sed 's/└/#/g; s/──/--/g; s/├/#/g; s/│ /|/g; s/│/|/g'

scopefile :; @tree ./src/ | sed 's/└/#/g' | awk -F '── ' '!/\.sol$$/ { path[int((length($$0) - length($$2))/2)] = $$2; next } { p = "src"; for(i=2; i<=int((length($$0) - length($$2))/2); i++) if (path[i] != "") p = p "/" path[i]; print p "/" $$2; }' > scope.txt

aderyn :; aderyn . -o ./docs/aderyn-report.md -x test,script,interfaces

coverage :; forge coverage --rpc-url $(RPC_ETH) --report lcov && genhtml lcov.info -o report --branch-coverage --via-ir

# -----DistractionRecorder & AccessRegistry----- #
# Deploy to Ethereum Mainnet
deploy-mainnet:
	@echo "Deploying to Ethereum Mainnet..."
	@forge script script/DeployMainnet.s.sol:DeployMainnet \
		--rpc-url $(RPC_ETH) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

# Deploy to Sepolia Testnet
deploy-sepolia:
	@echo "Deploying to Sepolia Testnet..."
	@forge script script/DeploySepolia.s.sol:DeploySepolia \
		--rpc-url $(RPC_ETH_SEPOLIA) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

# Deploy to Holesky Testnet
deploy-holesky:
	@echo "Deploying to Holesky Testnet..."
	@forge script script/DeployHolesky.s.sol:DeployHolesky \
		--rpc-url $(RPC_ETH_HOLESKY) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv

# Deploy to local Anvil for testing
deploy-local:
	@echo "Deploying to local Anvil..."
	@forge script script/DeployLocal.s.sol:Deploy \
		--rpc-url http://localhost:8545 \
		--broadcast \
		-vvvv


# Dry-run deployment (simulation without broadcasting)
deploy-mainnet-dry:
	@echo "Simulating Mainnet deployment..."
	@forge script script/DeployMainnet.s.sol:DeployMainnet \
		--rpc-url $(RPC_ETH) \
		-vvvv

deploy-sepolia-dry:
	@echo "Simulating Sepolia deployment..."
	@forge script script/DeploySepolia.s.sol:DeploySepolia \
		--rpc-url $(RPC_ETH_SEPOLIA) \
		-vvvv

deploy-holesky-dry:
	@echo "Simulating Holesky deployment..."
	@forge script script/DeployHolesky.s.sol:DeployHolesky \
		--rpc-url $(RPC_ETH_HOLESKY) \
		-vvvv

