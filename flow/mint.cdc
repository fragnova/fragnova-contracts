// Transaction2.cdc

import HastenScript from 0xf8d6e0586b0a20c7

// This transaction allows the Minter account to mint an NFT
// and deposit it into its collection.

transaction {
  // The reference to the collection that will be receiving the NFT
  let receiverRef: &{HastenScript.NFTReceiver}

  // The reference to the Minter resource stored in account storage
  let minterRef: &HastenScript.NFTMinter

  prepare(acct: AuthAccount) {
    // Get the owner's collection capability and borrow a reference
    self.receiverRef = acct.getCapability<&{HastenScript.NFTReceiver}>(/public/NFTReceiver)
      .borrow()
      ?? panic("Could not borrow receiver reference")

    // Borrow a capability for the NFTMinter in storage
    self.minterRef = acct.borrow<&HastenScript.NFTMinter>(from: /storage/NFTMinter)
      ?? panic("could not borrow minter reference")
  }

  execute {
    // Use the minter reference to mint an NFT, which deposits
    // the NFT into the collection that is sent as a parameter.
    let newNFT <- self.minterRef.mintNFT(code: [7 as UInt8, 1 as UInt8, 1 as UInt8])

    self.receiverRef.deposit(token: <-newNFT)

    log("NFT Minted and deposited to Account 2's Collection")
  }
}
