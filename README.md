# splits-vesting

Install [foundry](https://github.com/gakonst/foundry#installation), then run `forge install` and `make build` to compile the contracts. See package.json & makefile for the full list of commands/scripts

## lint

`make lint`

## test

`make test` - compile & test the contracts

`make trace` - produces a trace of any failing tests

## other tests

### slither

`slither src/VestingModule.sol`
`slither src/VestingModuleFactory.sol`

### mythril

`docker run -it --rm -v$(pwd):/home/mythril mythril/myth -v4 analyze src/VestingModule.sol --solc-json mythril.config.json --solv 0.8.13`
`docker run -it --rm -v$(pwd):/home/mythril mythril/myth -v4 analyze src/VestingModuleFactory.sol --solc-json mythril.config.json --solv 0.8.13`
