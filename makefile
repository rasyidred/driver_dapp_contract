-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil scopefile

DEFAULT_ANVIL_KEY := 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6

all: remove install build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm --force .git/index.lock && rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# install dependencies, for the latest compiler and circom-zkp submodule
install:
	forge install foundry-rs/forge-std\
		&& forge i OpenZeppelin/openzeppelin-contracts

# Obtain ABI in json
abi-access-registry:
	jq '.abi' out/AccessRegistry.sol/AccessRegistry.json > abiAccessRegistry.json
	@echo "ABI generated: abiAccessRegistry.json"

abi-distraction-recorder:
	jq '.abi' out/DistractionRecorder.sol/DistractionRecorder.json > abiDistractionRecorder.json
	@echo "ABI generated: abiDistractionRecorder.json"

# Update Dependencies
update:; forge update

build:; forge build 

test :; forge test 

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

coverage :; forge coverage --rpc-url $(RPC_BESU) --report lcov && genhtml lcov.info -o report --branch-coverage --via-ir

# -----DistractionRecorder & AccessRegistry----- #
# Deploy to private Besu network
deploy-besu:
	@echo "Deploying to private Besu network..."
	@forge script script/DeploymentScript.s.sol:DeploymentScript \
		--rpc-url $(RPC_BESU) \
		--broadcast \
		-vvvv

# Dry-run: simulate without broadcasting
deploy-besu-dry:
	@echo "Simulating Besu deployment (no broadcast)..."
	@forge script script/DeploymentScript.s.sol:DeploymentScript \
		--rpc-url $(RPC_BESU) \
		-vvvv

# Deploy to local Anvil for testing
deploy-local:
	@echo "Deploying to local Anvil..."
	@forge script script/DeploymentScript.s.sol:DeploymentScript \
		--rpc-url http://localhost:8545 \
		--broadcast \
		-vvvv