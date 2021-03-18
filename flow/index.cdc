import HastenUtility from "./utility.cdc"

pub contract HastenIndex {
  pub resource NFTReference {
    pub let tokenOwner: Address?

     init(tokenOwner: Address?) {
      self.tokenOwner = tokenOwner
    }
  }

  pub resource interface Index {
    pub fun find(hashId: UInt256): Address?
    pub fun update(hashId: UInt256, ownerAddr: Address)
  }

  pub resource IndexImpl : Index {
    pub var nftToAddr: @{UInt256: NFTReference}

    init() {
       self.nftToAddr <- {}
    }

    pub fun find(hashId: UInt256): Address? {
      if self.nftToAddr[hashId] != nil {
        let nft = &self.nftToAddr[hashId] as &NFTReference
        return nft.tokenOwner
      } else {
        return nil
      }
    }

    pub fun update(hashId: UInt256, ownerAddr: Address) {
      let newRef <- create NFTReference(tokenOwner: ownerAddr)
      let oldRef <- self.nftToAddr.insert(key: hashId, <- newRef)
      destroy oldRef
    }

    destroy() {
      destroy self.nftToAddr
    }
  }


  init() {
    // store an empty NFT Collection in account storage
    self.account.save(<- create IndexImpl(), to: /storage/Index)

    // publish a reference to the Collection in storage
    self.account.link<&{Index}>(/public/HastenIndex, target: /storage/Index)
  }
}