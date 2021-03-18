// NFTv2.cdc
//
// This is a complete version of the ExampleNFT contract
// that includes withdraw and deposit functionality, as well as a
// collection resource that can be used to bundle NFTs together.
//
// It also includes a definition for the Minter resource,
// which can be used by admins to mint new NFTs.
//
// Learn more about non-fungible tokens in this tutorial: https://docs.onflow.org/docs/non-fungible-tokens

import Crypto
import HastenUtility from 0xf8d6e0586b0a20c7
import HastenIndex from 0xf8d6e0586b0a20c7

pub contract HastenScript {
  pub event NewReceiver(addr: Address?)

  pub event Withdraw(id: UInt256, addr: Address?)

  pub event Deposit(id: UInt256, addr: Address?)

  // Declare the NFT resource type
  pub resource NFT {
    // The unique ID that differentiates each NFT
    pub let hashId: UInt256

    // The binary compressed code
    pub let code: [UInt8]

    // Initialize both fields in the init function
    init(hashId: UInt256, code: [UInt8]) {
      self.hashId = hashId
      self.code = code
    }
  }

  // We define this interface purely as a way to allow users
  // to create public, restricted references to their NFT Collection.
  // They would use this to only expose the deposit, getIDs,
  // and idExists fields in their Collection
  pub resource interface NFTReceiver {
    pub fun deposit(token: @NFT)

    pub fun getIDs(): [UInt256]

    pub fun idExists(id: UInt256): Bool

    pub fun view(id: UInt256): &NFT;
  }

  // The definition of the Collection resource that
  // holds the NFTs that a user owns
  pub resource Collection: NFTReceiver {
    // dictionary of NFT conforming tokens
    // NFT is a resource type with an `UInt64` ID field
    pub var ownedNFTs: @{UInt256: NFT}

    // Initialize the NFTs field to an empty collection
    init () {
      self.ownedNFTs <- {}
      emit NewReceiver(addr: self.owner?.address)
    }

    // withdraw
    //
    // Function that removes an NFT from the collection
    // and moves it to the calling context
    pub fun withdraw(withdrawID: UInt256): @NFT {
      // If the NFT isn't found, the transaction panics and reverts
      let token <- self.ownedNFTs.remove(key: withdrawID)!
      emit Withdraw(id: token.hashId, addr: self.owner?.address)
      return <-token
    }

    // deposit
    //
    // Function that takes a NFT as an argument and
    // adds it to the collections dictionary
    pub fun deposit(token: @NFT) {
      // update the global index
      let indexAccount = getAccount(0xf8d6e0586b0a20c7)
      let index = indexAccount.getCapability<&{HastenIndex.Index}>(/public/HastenIndex)
                        .borrow() ?? panic("Could not borrow index")
      index.update(hashId: token.hashId, ownerAddr: self.owner!.address)

      // emit a deposit event
      emit Deposit(id: token.hashId, addr: self.owner?.address)

      // add the new token to the dictionary with a force assignment
      // if there is already a value at that key, it will fail and revert
      self.ownedNFTs[token.hashId] <-! token
    }

    // idExists checks to see if a NFT
    // with the given ID exists in the collection
    pub fun idExists(id: UInt256): Bool {
      return self.ownedNFTs[id] != nil
    }

    // getIDs returns an array of the IDs that are in the collection
    pub fun getIDs(): [UInt256] {
      return self.ownedNFTs.keys
    }

    pub fun view(id: UInt256): &NFT {
      return &self.ownedNFTs[id] as &NFT
    }

    destroy() {
      destroy self.ownedNFTs
    }
  }

  // creates a new empty Collection resource and returns it
  pub fun createEmptyCollection(): @Collection {
    return <- create Collection()
  }

  // NFTMinter
  //
  // Resource that would be owned by an admin or by a smart contract
  // that allows them to mint new NFTs when needed
  pub resource NFTMinter {
    pub var mintedNFTs: [UInt256]

    init () {
      self.mintedNFTs = []
    }

    pub fun mintNFT(code: [UInt8]): @NFT {
      let hashId = HastenUtility.sha3_160(bytes: code)

      if self.mintedNFTs.contains(hashId) {
        panic("Code was already minted")
      }

      // create a new NFT
      var newNFT <- create NFT(hashId: hashId, code: code)

      self.mintedNFTs.append(hashId)

      return <-newNFT
    }
  }

  init() {
    // store an empty NFT Collection in account storage
    self.account.save(<- self.createEmptyCollection(), to: /storage/NFTCollection)

    // publish a reference to the Collection in storage
    self.account.link<&{NFTReceiver}>(/public/NFTReceiver, target: /storage/NFTCollection)

    // store a minter resource in account storage
    self.account.save(<- create NFTMinter(), to: /storage/NFTMinter)
  }
}
