/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

import HastenScript from 0xf8d6e0586b0a20c7
import IHastenScript from 0xf8d6e0586b0a20c7

// This transaction configures a user's account
// to use the Script contract by creating a new empty collection,
// storing it in their account storage, and publishing a capability
transaction {
    prepare(acct: AuthAccount) {

        // Create a new empty collection
        let collection <- HastenScript.createEmptyCollection()

        // store the empty Script Collection in account storage
        acct.save<@HastenScript.Collection>(<-collection, to: /storage/HastenScriptCollectionM0m0)

        log("Collection created for account 1")

        // create a public capability for the Collection
        acct.link<&{IHastenScript.ScriptReceiver}>(/public/HastenScriptReceiverM0m0, target: /storage/HastenScriptCollectionM0m0)

        log("Capability created")
    }
}
