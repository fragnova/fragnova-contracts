/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

import HastenScript from 0xf8d6e0586b0a20c7
import IHastenScript from 0xf8d6e0586b0a20c7

// This transaction transfers an Script from one user's collection
// to another user's collection.
transaction {

    // The field that will hold the Script as it is being
    // transferred to the other account
    let transferToken: @IHastenScript.Script

    prepare(acct: AuthAccount) {

        // Borrow a reference from the stored collection
        let collectionRef = acct.borrow<&HastenScript.Collection>(from: /storage/HastenScriptCollectionM0m0)
            ?? panic("Could not borrow a reference to the owner's collection")

        // Call the withdraw function on the sender's Collection
        // to move the Script out of the collection
        self.transferToken <- collectionRef.withdraw(withdrawID: UInt256(977254950727332713390919558565142167926186649569))
    }

    execute {
        // Get the recipient's public account object
        let recipient = getAccount(0x01cf0e2f2f715450)

        // Get the Collection reference for the receiver
        // getting the public capability and borrowing a reference from it
        let receiverRef = recipient.getCapability<&{IHastenScript.ScriptReceiver}>(/public/HastenScriptReceiverM0m0)
            .borrow()
            ?? panic("Could not borrow receiver reference")

        // Deposit the Script in the receivers collection
        receiverRef.deposit(token: <-self.transferToken)

        log("Script ID 1 transferred from account 2 to account 1")
    }
}
