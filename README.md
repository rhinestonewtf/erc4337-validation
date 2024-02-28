# ERC4337 Validation

**A library to validate the [ERC-4337 rules](https://github.com/eth-infinitism/account-abstraction/blob/develop/erc/ERCS/erc-7562.md) within Foundry**

This library allows you to validate:

- [ ] Banned opcodes
- [x] Banned storage locations
- [x] Disallowed `*CALLs`
- [x] Disallowed use of `EXT*` opcodes
- [x] Disallowed use `CREATE` opcode

It also supports both `v0.6` and `v0.7` of ERC-4337.

> This library is in active development and is subject to breaking changes. If you spot a bug, please take out an issue and we will fix it as soon as we can.

## Installation

### With Foundry

```bash
forge install rhinestonewtf/erc4337-validation
```

### Using a package manager

```bash
pnpm i @rhinestone/erc4337-validation
```

## Usage

To use this library, simply import the `Simulator` and call

```solidity
Simulator.simulateUserOp(userOp, entryPointAddress);
```

If the userOp breaks any of the rules, the function will revert with a message indicating which rule was broken.

Note that the `entryPointAddress` needs to be the address of the `EntryPointSimulations` contract if you are using v0.7 of ERC-4337. For an example see the [Simulator test](./test/Simulator.t.sol), the [Simulator test v0.6](./test/SimulatorV060.t.sol) and the relevant [test bases](./test/utils).

## Contributing

For feature or change requests, feel free to open a PR, start a discussion or get in touch with us.

For guidance on how to create PRs, see the [CONTRIBUTING](./CONTRIBUTING.md) guide.

## Credits

- [Dror](https://github.com/drortirosh): For the implementation approach and an initial prototype

## Authors ✨

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="https://twitter.com/abstractooor"><img src="https://avatars.githubusercontent.com/u/26718079" width="100px;" alt=""/><br /><sub><b>Konrad</b></sub></a><br /><a href="https://github.com/rhinestonewtf/erc4337-validation/commits?author=kopy-kat" title="Code">💻</a> </td>
    
  </tr>
</table>
