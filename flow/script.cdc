// Scriptv2.cdc
//
// This is a complete version of the ExampleScript contract
// that includes withdraw and deposit functionality, as well as a
// collection resource that can be used to bundle Scripts together.
//
// It also includes a definition for the Minter resource,
// which can be used by admins to mint new Scripts.
//
// Learn more about non-fungible tokens in this tutorial: https://docs.onflow.org/docs/non-fungible-tokens

import Crypto
import HastenUtility from "./utility.cdc"
import HastenIndex from "./index.cdc"
import IHastenScript from "./iscript.cdc"

pub contract HastenScript {
  // The definition of the Collection resource that
  // holds the Scripts that a user owns
  pub resource Collection : IHastenScript.ScriptReceiver {
    // dictionary of Script conforming tokens
    // Script is a resource type with an `UInt64` ID field
    access(self) var ownedScripts: @{UInt256: IHastenScript.Script}

    // Initialize the Scripts field to an empty collection
    init () {
      self.ownedScripts <- {}
      emit NewReceiver(addr: self.owner?.address)
    }

    // withdraw
    //
    // Function that removes an Script from the collection
    // and moves it to the calling context
    pub fun withdraw(withdrawID: UInt256): @IHastenScript.Script {
      // If the Script isn't found, the transaction panics and reverts
      let token <- self.ownedScripts.remove(key: withdrawID)!
      emit Withdraw(id: token.hashId, addr: self.owner?.address)
      return <-token
    }

    // deposit
    //
    // Function that takes a Script as an argument and
    // adds it to the collections dictionary
    pub fun deposit(token: @IHastenScript.Script) {
      // emit a deposit event
      emit Deposit(id: token.hashId, addr: self.owner?.address)
      // add the new token to the dictionary with a force assignment
      // if there is already a value at that key, it will fail and revert
      self.ownedScripts[token.hashId] <-! token
    }

    // idExists checks to see if a Script
    // with the given ID exists in the collection
    pub fun idExists(id: UInt256): Bool {
      return self.ownedScripts[id] != nil
    }

    // getIDs returns an array of the IDs that are in the collection
    pub fun getIDs(): [UInt256] {
      return self.ownedScripts.keys
    }

    pub fun view(id: UInt256): &{IHastenScript.ScriptView} {
      return &self.ownedScripts[id] as &{IHastenScript.ScriptView}
    }

    pub fun get(id: UInt256) : &IHastenScript.Script {
      return &self.ownedScripts[id] as &IHastenScript.Script
    }

    destroy() {
      destroy self.ownedScripts
    }
  }

  // creates a new empty Collection resource and returns it
  pub fun createEmptyCollection(): @Collection {
    return <- create Collection()
  }

  // ScriptMinter
  pub fun mintWithEnv(metadata: String, code: [UInt8], environment: [UInt8]): @IHastenScript.Script {
    let hashId = HastenUtility.sha3_160(bytes: code)

    // find if the script already exists in the global index
    let indexAccount = getAccount(HastenUtility.ownerAddress())
    let index = indexAccount.getCapability<&{HastenIndex.Index}>(/public/HastenIndex)
                      .borrow() ?? panic("Could not borrow index")
    let maybeOwner = index.find(hashId: hashId)
    if let existingOwner = maybeOwner {
      panic("This Script already exists")
    }

    // create a new Script
    var newScript <- IHastenScript.createScript(metadata: metadata, code: code, environment: environment)

    return <-newScript
  }

  pub fun mint(metadata: String, code: [UInt8]): @IHastenScript.Script {
    return <- HastenScript.mintWithEnv(metadata: metadata, code: code, environment: [])
  }

  init() {
    // store an empty Script Collection in account storage
    self.account.save(<- self.createEmptyCollection(), to: /storage/HastenScriptCollectionM0m0)

    // publish a reference to the Collection in storage
    self.account.link<&{IHastenScript.ScriptReceiver}>(/public/HastenScriptReceiverM0m0, target: /storage/HastenScriptCollectionM0m0)
  }

  pub event NewReceiver(addr: Address?)
  pub event Withdraw(id: UInt256, addr: Address?)
  pub event Deposit(id: UInt256, addr: Address?)
}
