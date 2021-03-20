// Transaction2.cdc

import HastenScript from 0xf8d6e0586b0a20c7
import HastenIndex from 0xf8d6e0586b0a20c7
import HastenUtility from 0xf8d6e0586b0a20c7
import IHastenScript from 0xf8d6e0586b0a20c7

// This transaction allows the Minter account to mint an Script
// and deposit it into its collection.

transaction {
  // The reference to the collection that will be receiving the Script
  let receiverRef: &{IHastenScript.ScriptReceiver}

  prepare(acct: AuthAccount) {
    // Get the owner's collection capability and borrow a reference
    self.receiverRef = acct.getCapability<&{IHastenScript.ScriptReceiver}>(/public/HastenScriptReceiverM0m0)
      .borrow()
      ?? panic("Could not borrow receiver reference")
  }

  execute {
    // Use the minter to mint an Script, which deposits
    // the Script into the collection that is sent as a parameter.
    let newScript <- HastenScript.mint(metadata: "Hello", code: [7 as UInt8, 1 as UInt8, 1 as UInt8])
    let newId = newScript.hashId
    self.receiverRef.deposit(token: <-newScript)

    // update the global index
    let view = self.receiverRef.view(id: newId)
    let indexAccount = getAccount(HastenUtility.ownerAddress())
    let index = indexAccount.getCapability<&{HastenIndex.Index}>(/public/HastenIndex)
                      .borrow() ?? panic("Could not borrow index")
    index.update(script: view!)

    log("Script Minted and deposited to Account 2's Collection")
  }
}
