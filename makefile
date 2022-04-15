# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env.local

# formatting
lint						:; yarn lint:fix

# deps
update					:; forge update

# Build & test
build						:; forge build
test						:; forge test
trace   				:; forge test -vvv
report 					:; forge test --gas-report
snapshot 				:; forge test --gas-report > .gas-snapshot
clean  					:; forge clean

# Deploy & verify
# deploy					:; @forge create ./src/$(contract).sol:$(contract) --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY}
deploy-mainnet	:; @forge create ./src/$(contract).sol:$(contract) --rpc-url https://eth-mainnet.alchemyapi.io/v2/${ALCHEMY_MAINNET_KEY} --private-key ${PRIVATE_KEY}
deploy-ropsten	:; @forge create ./src/$(contract).sol:$(contract) --rpc-url https://eth-ropsten.alchemyapi.io/v2/${ALCHEMY_ROPSTEN_KEY} --private-key ${PRIVATE_KEY}
deploy-polygon		:; @forge create ./src/$(contract).sol:$(contract) --rpc-url https://polygon-mainnet.g.alchemy.com/v2/${ALCHEMY_POLYGON_KEY} --private-key ${PRIVATE_KEY}
deploy-mumbai		:; @forge create ./src/$(contract).sol:$(contract) --rpc-url https://polygon-mumbai.g.alchemy.com/v2/${ALCHEMY_MUMBAI_KEY} --private-key ${PRIVATE_KEY}
verify 					:; @forge verify-contract $(address) ./src/$(contract).sol:$(contract) ${ETHERSCAN_KEY} --compiler-version v0.8.13+commit.abaa5c0e --num-of-optimizations 200 --chain-id $(chain-id)
verify-check 		:; @forge verify-check $(guid) ${ETHERSCAN_KEY} --chain-id $(chain-id)

# types
typechain				:; forge clean && forge build && yarn typechain --target=ethers-v5 out/VestingModule.sol/VestingModule.json out/VestingModuleFactory.sol/VestingModuleFactory.json
