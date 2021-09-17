/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

import HastenScript from 0xf8d6e0586b0a20c7
import HastenIndex from 0xf8d6e0586b0a20c7

transaction {
  let coll: @HastenScript.Collection?
  let index: @HastenIndex.IndexImpl?


  prepare(acct: AuthAccount) {
    self.coll <- acct.load<@HastenScript.Collection>(from: /storage/HastenScriptCollectionM0m0)
    self.index <- acct.load<@HastenIndex.IndexImpl>(from: /storage/HastenIndex)
    acct.unlink(/public/ScriptReceiver)
    acct.unlink(/public/HastenIndex)
  }
  execute {
    destroy self.coll
    destroy self.index
  }
}