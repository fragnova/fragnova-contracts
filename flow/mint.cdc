// Transaction2.cdc

import HastenScript from 0xf8d6e0586b0a20c7

// This transaction allows the Minter account to mint an Script
// and deposit it into its collection.

transaction {
  // The reference to the collection that will be receiving the Script
  let receiverRef: &{HastenScript.ScriptReceiver}

  prepare(acct: AuthAccount) {
    // Get the owner's collection capability and borrow a reference
    self.receiverRef = acct.getCapability<&{HastenScript.ScriptReceiver}>(/public/ScriptReceiver)
      .borrow()
      ?? panic("Could not borrow receiver reference")
  }

  execute {
    // Use the minter to mint an Script, which deposits
    // the Script into the collection that is sent as a parameter.
    let newScript <- HastenScript.mintScript(code: [7 as UInt8, 1 as UInt8, 1 as UInt8])

    self.receiverRef.deposit(token: <-newScript)

    log("Script Minted and deposited to Account 2's Collection")
  }
}
