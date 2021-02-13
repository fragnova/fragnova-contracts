var nft = artifacts.require("HastenProgram");

contract("HastenProgram", accounts => {
  it("should upload a program", async () => {
    const contract = await nft.deployed();
    assert.equal(await contract.totalSupply.call(), 0);
    const emptyCode = new Uint8Array(1024);
    const tx = await contract.upload(accounts[0], "", emptyCode);
    assert.equal(tx.logs[0].args.tokenId.toString(), "82244645650067078051647883681477212594888008908680932184588990116864531889524");
    assert.equal(tx.receipt.gasUsed, 228906);
    assert.equal(await contract.totalSupply.call(), 1);
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[0]);
    const program = await contract.program.call(tx.logs[0].args.tokenId);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal(program.programBytes, codeHex);
  });

  it("should not upload a program", async () => {
    try {
      const contract = await nft.deployed();
      assert.equal(await contract.totalSupply.call(), 1);
      const emptyCode = new Uint8Array(1024);
      await contract.upload(accounts[0], "", emptyCode, emptyCode);
    } catch (e) {
      assert(e.toString() == "Error: Returned error: VM Exception while processing transaction: revert ERC721: token already minted -- Reason given: ERC721: token already minted.");
      return;
    }
    assert(false, "expected exception not thrown");
  });

  it("should upload a program", async () => {
    const contract = await nft.deployed();
    assert.equal(await contract.totalSupply.call(), 1);
    const emptyCode = new Uint8Array(1024);
    emptyCode[0] = 1; // make a small change in order to succeed
    const tx = await contract.upload(accounts[0], "", emptyCode, emptyCode);
    assert.equal(tx.logs[0].args.tokenId.toString(), "22245867104185935282213184455643255424572845908357372064232261761039889590899");
    assert.equal(tx.receipt.gasUsed, 291293);
    assert.equal(await contract.totalSupply.call(), 2);
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[0]);
    const program = await contract.program.call(tx.logs[0].args.tokenId);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal(program.programBytes, codeHex);
    assert.equal(program.environment, codeHex);
  });

  it("should not update a program's environment", async () => {
    try {
      const contract = await nft.deployed();
      const emptyCode = new Uint8Array(30);
      await contract.update(web3.utils.toHex("82244645650067078051647883681477212594888008908680932184588990116864531889524"), emptyCode, { from: accounts[1] });
    } catch (e) {
      assert(e.reason == "Only the owner of the program can update its environment");
      return;
    }
    assert(false, "expected exception not thrown");
  });

  it("should update a program's environment", async () => {
    const contract = await nft.deployed();
    const emptyCode = new Uint8Array(30);
    const tx = await contract.update(web3.utils.toHex("82244645650067078051647883681477212594888008908680932184588990116864531889524"), emptyCode, { from: accounts[0] });
    const program = await contract.program.call(web3.utils.toHex("82244645650067078051647883681477212594888008908680932184588990116864531889524"));
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal(program.environment, codeHex);
  });
});