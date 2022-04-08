# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env.local

# formatting
lint						:; yarn prettier:fix

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
deploy					:; @forge create ./src/$(contract).sol:$(contract) --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY}
verify 					:; @forge verify-contract --compiler-version v0.8.13+commit.abaa5c0e 0x9f7d513e0c528566b6ba28a886e4dad447169fa6 --num-of-optimizations 200 ./src/$(contract).sol:$(contract) --chain-id $(chain) ${ETHERSCAN_KEY}
verify-check 		:; @forge verify-check $(guid) ${ETHERSCAN_KEY}
