const { keccak256, hexToBytes } = require('web3-utils')

var nft = artifacts.require("HastenScript");
var modNft = artifacts.require("HastenMod");
var dao = artifacts.require("HastenDAOToken");

function getExpectedAddress(address, bytecode, salt) {
  const arg = hexToBytes('0xff')
    .concat(hexToBytes(address))
    .concat(hexToBytes(salt))
    .concat(hexToBytes(keccak256(bytecode)))
  return '0x' + keccak256(arg).slice(26)
}

contract("HastenScript", accounts => {
  const scriptHash = web3.utils.toHex("82244645650067078051647883681477212594888008908680932184588990116864531889524");

  it("should upload a script", async () => {
    const contract = await nft.deployed();
    // console.log(getExpectedAddress("0xce0042B868300000d44A59004Da54A005ffdcf9f", nft.bytecode, "0x711"));
    // console.log(contract.address);
    scriptContract = contract;
    assert.equal(await contract.totalSupply.call(), 0);
    const emptyCode = new Uint8Array(1024);
    const tx = await contract.upload("", emptyCode, { from: accounts[0] });
    assert.equal(tx.logs[0].args.tokenId.toString(), "82244645650067078051647883681477212594888008908680932184588990116864531889524");
    assert.equal(tx.receipt.gasUsed, 228502);
    assert.equal(await contract.totalSupply.call(), 1);
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[0]);
    const script = await contract.script.call(tx.logs[0].args.tokenId);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal(script.scriptBytes, codeHex);
  });

  it("should not upload a script", async () => {
    try {
      const contract = await nft.deployed();
      assert.equal(await contract.totalSupply.call(), 1);
      const emptyCode = new Uint8Array(1024);
      await contract.uploadWithEnvironment("", emptyCode, emptyCode, { from: accounts[0] });
    } catch (e) {
      assert(e.toString() == "Error: Returned error: VM Exception while processing transaction: revert ERC721: token already minted -- Reason given: ERC721: token already minted.");
      return;
    }
    assert(false, "expected exception not thrown");
  });

  it("should upload a script with environment", async () => {
    const contract = await nft.deployed();
    assert.equal(await contract.totalSupply.call(), 1);
    const emptyCode = new Uint8Array(1024);
    emptyCode[0] = 1; // make a small change in order to succeed
    const tx = await contract.uploadWithEnvironment("", emptyCode, emptyCode, { from: accounts[0] });
    assert.equal(tx.logs[0].args.tokenId.toString(), "22245867104185935282213184455643255424572845908357372064232261761039889590899");
    assert.equal(tx.receipt.gasUsed, 290976);
    assert.equal(await contract.totalSupply.call(), 2);
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[0]);
    const script = await contract.script.call(tx.logs[0].args.tokenId);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal(script.scriptBytes, codeHex);
    assert.equal(script.environment, codeHex);
  });

  it("should not update a script's environment", async () => {
    try {
      const contract = await nft.deployed();
      const emptyCode = new Uint8Array(30);
      await contract.update(scriptHash, emptyCode, { from: accounts[1] });
    } catch (e) {
      assert(e.reason == "Only the owner of the script can update its environment");
      return;
    }
    assert(false, "expected exception not thrown");
  });

  it("should update a script's environment", async () => {
    const contract = await nft.deployed();
    const emptyCode = new Uint8Array(30);
    await contract.update(scriptHash, emptyCode, { from: accounts[0] });
    const script = await contract.script.call(scriptHash);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal(script.environment, codeHex);
  });

  it("should upload a mod", async () => {
    await nft.deployed();
    const dao20 = await dao.deployed();
    const contract = await modNft.deployed();
    assert.equal(await dao20.balanceOf.call(contract.address), web3.utils.toWei("1024", "ether"));
    const empty = new Uint8Array(1024);
    const tx = await contract.upload("", scriptHash, empty, { from: accounts[0] });
    assert.equal(tx.logs[0].args.tokenId.toString(), 1);
    assert.equal(tx.receipt.gasUsed, 275578);
    assert.equal(await contract.totalSupply.call(), 1);
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[0]);
    const script = await contract.script.call(tx.logs[0].args.tokenId);
    const codeHex = web3.utils.bytesToHex(empty);
    assert.equal(script.scriptBytes, codeHex);
    // mint should not trigger rewards
    assert.equal(await dao20.balanceOf.call(contract.address), web3.utils.toWei("1024", "ether"));
  });

  it("should transfer a mod", async () => {
    await nft.deployed();
    const dao20 = await dao.deployed();
    // console.log(web3.utils.fromWei((await dao20.totalSupply.call()).toString(), "ether"));
    const contract = await modNft.deployed();
    await contract.safeTransferFrom(accounts[0], accounts[1], 1);
    assert.equal(await contract.ownerOf.call(1), accounts[1]);
    // check reward
    assert.equal(await dao20.balanceOf.call(contract.address), web3.utils.toWei("1023990", "milli"));
  });

  it("should not upload a mod", async () => {
    try {
      await nft.deployed();
      await dao.deployed();
      const contract = await modNft.deployed();
      const empty = new Uint8Array(1024);
      const tx = await contract.upload("", scriptHash, empty, { from: accounts[1] });
      assert.equal(tx.logs[0].args.tokenId.toString(), 1);
      assert.equal(tx.receipt.gasUsed, 275451);
      assert.equal(await contract.totalSupply.call(), 1);
      assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[1]);
      const script = await contract.script.call(tx.logs[0].args.tokenId);
      const codeHex = web3.utils.bytesToHex(empty);
      assert.equal(script.scriptBytes, codeHex);
    } catch (e) {
      assert(e.reason == "Only the owner of the script can upload mods");
      return;
    }
    assert(false, "expected exception not thrown");
  });
});
