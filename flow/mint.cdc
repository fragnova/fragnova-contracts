// Transaction2.cdc

import HastenScript from 0xf8d6e0586b0a20c7

// This transaction allows the Minter account to mint an Script
// and deposit it into its collection.

transaction {
  // The reference to the collection that will be receiving the Script
  let receiverRef: &{HastenScript.ScriptReceiver}

  // The reference to the Minter resource stored in account storage
  let minterRef: &HastenScript.ScriptMinter

  prepare(acct: AuthAccount) {
    // Get the owner's collection capability and borrow a reference
    self.receiverRef = acct.getCapability<&{HastenScript.ScriptReceiver}>(/public/ScriptReceiver)
      .borrow()
      ?? panic("Could not borrow receiver reference")

    // Borrow a capability for the ScriptMinter in storage
    self.minterRef = acct.borrow<&HastenScript.ScriptMinter>(from: /storage/ScriptMinter)
      ?? panic("could not borrow minter reference")
  }

  execute {
    // Use the minter reference to mint an Script, which deposits
    // the Script into the collection that is sent as a parameter.
    let newScript <- self.minterRef.mintScript(code: [7 as UInt8, 1 as UInt8, 1 as UInt8])

    self.receiverRef.deposit(token: <-newScript)

    log("Script Minted and deposited to Account 2's Collection")
  }
}
