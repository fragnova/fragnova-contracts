var nft = artifacts.require("HastenProgram");

contract("HastenProgram", accounts => {
  it("should upload a program", async () => {
    const contract = await nft.deployed();
    assert.equal(await contract.totalSupply.call(), 0);
    const emptyCode = new Uint8Array(1024);
    const tx = await contract.upload(accounts[0], emptyCode);
    assert.equal(tx.logs[0].args.tokenId.toString(), "82244645650067078051647883681477212594888008908680932184588990116864531889524");
    assert.equal(tx.receipt.gasUsed, 225227);
    assert.equal(await contract.totalSupply.call(), 1);
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[0]);
    const program = await contract.program.call(tx.logs[0].args.tokenId);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal(program, codeHex);
  });
});