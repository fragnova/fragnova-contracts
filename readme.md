# Hasten Smart Contracts v1

Solidity and Flow contracts to support **hasten.app** NFTs and FTs.

## Deterministic contracts (EVM chains)

The following raw transactions can be used by anyone to deploy Hasten contracts to any chain.

The resulting contracts will have always the same address no matter on which chain they are. Making the ecosystem reliably global!

More details here https://eips.ethereum.org/EIPS/eip-2470

use the `deploy.edn` script to find transactions and addresses

* Utility
  * Gas Used by Transaction: 1,145,728 (57.29%)
* Entity
  * Gas Used by Transaction: 3,624,247 (90.61%)
* Vault
  * Gas Used by Transaction: 579,567 (57.96%)
* Fragment
  * Gas Used by Transaction: 4,371,203 (72.85%)
* Admin
  * Gas Used by Transaction: 494,368 (49.44%)
* Fragment Proxy
  * Gas Used by Transaction: 554,693 (55.47%)

### AVAX Factory:

Sadly their gas is off and the EIP-2470 data cannot be used
I used this but means addresses will be different unless we accept to pay more to deploy a new factory on eth:
```
0xf9016c8085746a52880083030d408080b90154608060405234801561001057600080fd5b50610134806100206000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80634af63f0214602d575b600080fd5b60cf60048036036040811015604157600080fd5b810190602081018135640100000000811115605b57600080fd5b820183602082011115606c57600080fd5b80359060200191846001830284011164010000000083111715608d57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250929550509135925060eb915050565b604080516001600160a01b039092168252519081900360200190f35b6000818351602085016000f5939250505056fea26469706673582212206b44f8a82cb6b156bfcc3dc6aadd6df4eefd204bc928a4397fd15dacf6d5320564736f6c634300060200331b83247000822470
```

https://cchain.explorer.avax-test.network/address/0x96d372104770465a36F7f05E8175975a2b4B2438/transactions

new one:
Creator: `0x53aab8351206a3eee51096c2be27d6e5ca9c5ecd`
Deployer: `0xe14B5aE0D1E8A4e9039D40e5BF203fD21E2f6241`
Well, this one is already on ETH :)
https://etherscan.io/address/0x53aab8351206a3eee51096c2be27d6e5ca9c5ecd
```
0xf9016c8085746a5288008303c4d88080b90154608060405234801561001057600080fd5b50610134806100206000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80634af63f0214602d575b600080fd5b60cf60048036036040811015604157600080fd5b810190602081018135640100000000811115605b57600080fd5b820183602082011115606c57600080fd5b80359060200191846001830284011164010000000083111715608d57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250929550509135925060eb915050565b604080516001600160a01b039092168252519081900360200190f35b6000818351602085016000f5939250505056fea26469706673582212206b44f8a82cb6b156bfcc3dc6aadd6df4eefd204bc928a4397fd15dacf6d5320564736f6c634300060200331b83247000822470
```

To run things via metamask - need to fund the creator account tho

> Max Txn Cost/Fee: 0.1235 Ether ($0.00)

> https://testnet.bscscan.com/tx/0xddacd6ad7f7ceac2940aff799ba2e370d7902e810b2635f0b593d03f6bedd791 BSC

> https://cchain.explorer.avax-test.network/tx/0xddacd6ad7f7ceac2940aff799ba2e370d7902e810b2635f0b593d03f6bedd791/internal-transactions AVAX

> https://explorer-mumbai.maticvigil.com/tx/0xddacd6ad7f7ceac2940aff799ba2e370d7902e810b2635f0b593d03f6bedd791/internal-transactions MATIC

```
await window.ethereum.request({ method: 'eth_requestAccounts' });
await ethereum.request({method: 'eth_sendRawTransaction', params: ["0xf9016c8085746a5288008303c4d88080b90154608060405234801561001057600080fd5b50610134806100206000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80634af63f0214602d575b600080fd5b60cf60048036036040811015604157600080fd5b810190602081018135640100000000811115605b57600080fd5b820183602082011115606c57600080fd5b80359060200191846001830284011164010000000083111715608d57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250929550509135925060eb915050565b604080516001600160a01b039092168252519081900360200190f35b6000818351602085016000f5939250505056fea26469706673582212206b44f8a82cb6b156bfcc3dc6aadd6df4eefd204bc928a4397fd15dacf6d5320564736f6c634300060200331b83247000822470"]});
```
