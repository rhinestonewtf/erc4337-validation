# ERC4337 Validation

**A library to validate the [ERC-4337 rules](https://eips.ethereum.org/EIPS/eip-7562) within Foundry**

This library allows you to validate:

- [x] Banned opcodes
- [x] Banned storage locations
- [x] Disallowed `*CALLs`
- [x] Disallowed use of `EXT*` opcodes
- [x] Disallowed use `CREATE` opcode

It also supports both `v0.6` and `v0.7` of ERC-4337.

> This library is in active development and is subject to breaking changes. If you spot a bug, please take out an issue and we will fix it as soon as we can.

## Using the library

### Installation

#### With Foundry

```bash
forge install rhinestonewtf/erc4337-validation
```

#### With a package manager

```bash
pnpm i @rhinestone/erc4337-validation
```

### Usage

To use this library, simply import the `Simulator` and set it up as follows:

```solidity
contract Example {
    using Simulator for PackedUserOperation; // or UserOperation

   function verify(PackedUserOperation memory userOp) external view {
        // Verify the ERC-4337 rules
        userOp.simulateUserOp(entryPointAddress);
    }
}
```

If the userOp breaks any of the rules, the function will revert with a message indicating which rule was broken.

Note that the `entryPointAddress` needs to be the address of the `EntryPointSimulations` contract if you are using v0.7 of ERC-4337. For an example see the [Simulator test](./test/Simulator.t.sol), the [Simulator test v0.6](./test/SimulatorV060.t.sol) and the relevant [test bases](./test/utils).

## Using this repo

To install the dependencies, run:

```bash
pnpm install
```

To build the project, run:

```bash
forge build
```

To run the tests, run:

```bash
forge test
```

## Contributing

For feature or change requests, feel free to open a PR, start a discussion or get in touch with us.

## Credits

- [Dror](https://github.com/drortirosh): For the implementation approach and an initial prototype
