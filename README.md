
# ERC20 Cairo Contract

This repository contains a simple implementation of the ERC20 token standard using the Cairo 2.7.


## Building

To build the  contracts, use the following command:

```shell
scarb build
```

## Declaring & Deploying

To declare and deploy your contract on the Sepolia testnet using `starkli`, run the following commands:

### Declare the Contract

```shell
starkli declare target/dev/cairo_erc20_ERC20.contract_class.json --network=sepolia --keystore="<PATH_TO_YOUR_KEYSTORE>"
```

### Deploy the Contract

```shell
starkli deploy --watch --account "<PATH_TO_YOUR_ACCOUNT_JSON>" --rpc <YOUR_RPC_URL> <YOUR_CONTRACT_CLASS_HASH> <NAME_IN_HEX> <SYMBOL_IN_HEX> <DECIMALS> <OWNER_ADDRESS>
```
