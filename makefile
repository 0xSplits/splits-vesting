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

# types
typechain				 :; forge clean && forge build && yarn typechain --target=ethers-v5 out/VestingModule.sol/VestingModule.json out/VestingModuleFactory.sol/VestingModuleFactory.json
