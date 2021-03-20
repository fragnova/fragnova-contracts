import HastenUtility from "./utility.cdc"
import IHastenScript from "./iscript.cdc"

pub contract HastenIndex {
  pub resource NFTReference {
    pub let tokenOwner: Address?

     init(tokenOwner: Address?) {
      self.tokenOwner = tokenOwner
    }
  }

  pub resource interface Index {
    pub fun find(hashId: UInt256): &{IHastenScript.ScriptView}?
    pub fun update(script: &{IHastenScript.ScriptView})
  }

  pub resource IndexImpl : Index {
    access(self) var nftToAddr: @{UInt256: NFTReference}

    init() {
       self.nftToAddr <- {}
    }

    pub fun find(hashId: UInt256): &{IHastenScript.ScriptView}? {
      if self.nftToAddr[hashId] != nil {
        let nft = &self.nftToAddr[hashId] as &NFTReference
        if let addr = nft.tokenOwner {
          let source = getAccount(addr)
          let mcoll = source.getCapability<&{IHastenScript.ScriptReceiver}>(/public/HastenScriptReceiverM0m0).borrow()
          if let coll = mcoll {
            let mscript = coll.view(id: hashId)
            if let script = mscript {
              return script
            } else {
              return nil
            }
          } else {
            return nil
          }
        } else {
          return nil
        }
      } else {
        return nil
      }
    }

    pub fun update(script: &{IHastenScript.ScriptView}) {
      let newRef <- create NFTReference(tokenOwner: script.owner!.address)
      let oldRef <- self.nftToAddr.insert(key: script.hashId, <- newRef)
      destroy oldRef
    }

    destroy() {
      destroy self.nftToAddr
    }
  }


  init() {
    // store an empty NFT Collection in account storage
    self.account.save(<- create IndexImpl(), to: /storage/HastenIndex)

    // publish a reference to the Collection in storage
    self.account.link<&{Index}>(/public/HastenIndex, target: /storage/HastenIndex)
  }
}