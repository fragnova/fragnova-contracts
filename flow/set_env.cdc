/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

import HastenScript from 0xf8d6e0586b0a20c7
import IHastenScript from 0xf8d6e0586b0a20c7
import HastenIndex from 0xf8d6e0586b0a20c7
import HastenUtility from 0xf8d6e0586b0a20c7

// This transaction transfers an Script from one user's collection
// to another user's collection.
transaction {
    // The field that will hold the Script as it is being
    // transferred to the other account
    let script: &IHastenScript.Script

    prepare(acct: AuthAccount) {
        let hashId = UInt256(977254950727332713390919558565142167926186649569)
        let coll = acct.borrow<&HastenScript.Collection>(from: /storage/HastenScriptCollectionM0m0) ?? panic("Could not borrow the index")
        self.script = coll.get(id: hashId)
    }

    execute {
      self.script.setEnvironment(environment: [])
    }
}
