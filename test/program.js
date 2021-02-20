const { Address, bufferToHex } = require("ethereumjs-util");
const { Transaction } = require("@ethereumjs/tx");
const { keccak256, hexToBytes, bytesToHex } = require("web3-utils");
const { BN } = require("bn.js");

var nft = artifacts.require("HastenScript");
var modNft = artifacts.require("HastenMod");
var dao = artifacts.require("HastenDAOToken");

function getExpectedAddress(address, bytecode, salt) {
  const arg = hexToBytes('0xff')
    .concat(hexToBytes(address))
    .concat(hexToBytes(salt))
    .concat(hexToBytes(keccak256(bytecode)))
  console.log(bytesToHex(arg));
  return '0x' + keccak256(arg).slice(26)
}

function composeCall(bytecode, salt) {
  return web3.eth.abi.encodeFunctionCall({
    name: 'deploy',
    type: 'function',
    inputs: [{
      type: 'bytes',
      name: '_initCode'
    }, {
      type: 'bytes32',
      name: '_salt'
    }]
  }, [bytecode, salt]);
}

function deterministicDeployment(contractBytes, gasCost) {
  console.log(composeCall(contractBytes, "0x711"));
  const deployTx = new Transaction({
    nonce: 0,
    gasPrice: new BN(web3.utils.toWei("100", "gwei"), 10),
    gasLimit: gasCost * 2, // tank a possible EVM gas cost raise
    value: 0,
    data: "0x608060405234801561001057600080fd5b50610134806100206000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80634af63f0214602d575b600080fd5b60cf60048036036040811015604157600080fd5b810190602081018135640100000000811115605b57600080fd5b820183602082011115606c57600080fd5b80359060200191846001830284011164010000000083111715608d57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250929550509135925060eb915050565b604080516001600160a01b039092168252519081900360200190f35b6000818351602085016000f5939250505056fea26469706673582212206b44f8a82cb6b156bfcc3dc6aadd6df4eefd204bc928a4397fd15dacf6d5320564736f6c63430006020033",
    // data: composeCall(contractBytes, "0x711"),
    v: 27,
    r: "0xBADA1",
    s: "0xC0FFEE"
  });
  return deployTx;
}

function fixSignature(signature) {
  // in geth its always 27/28, in ganache its 0/1. Change to 27/28 to prevent
  // signature malleability if version is 0/1
  // see https://github.com/ethereum/go-ethereum/blob/v1.8.23/internal/ethapi/api.go#L465
  let v = parseInt(signature.slice(130, 132), 16);
  if (v < 27) {
    v += 27;
  }
  const vHex = v.toString(16);
  return signature.slice(0, 130) + vHex;
}

// signs message in node (ganache auto-applies "Ethereum Signed Message" prefix)
async function signMessage(signer, messageHex = '0x') {
  return fixSignature(await web3.eth.sign(messageHex, signer));
};

function toEthSignedMessageHash(messageHex) {
  const messageBuffer = Buffer.from(messageHex.substring(2), 'hex');
  const prefix = Buffer.from(`\u0019Ethereum Signed Message:\n${messageBuffer.length}`);
  return web3.utils.sha3(Buffer.concat([prefix, messageBuffer]));
}

contract("HastenScript", accounts => {
  const scriptHash = web3.utils.toHex("82244645650067078051647883681477212594888008908680932184588990116864531889524");

  it("should upload a script", async () => {
    const prepareDeployer = async function () {
      const params = {
        from: accounts[0],
        to: "0xBb6e024b9cFFACB947A71991E386681B1Cd1477D",
        value: web3.utils.toWei("1", "ether"),
      };
      await web3.eth.sendTransaction(params);
      const receipt = await web3.eth.sendSignedTransaction("0xf9016c8085174876e8008303c4d88080b90154608060405234801561001057600080fd5b50610134806100206000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80634af63f0214602d575b600080fd5b60cf60048036036040811015604157600080fd5b810190602081018135640100000000811115605b57600080fd5b820183602082011115606c57600080fd5b80359060200191846001830284011164010000000083111715608d57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250929550509135925060eb915050565b604080516001600160a01b039092168252519081900360200190f35b6000818351602085016000f5939250505056fea26469706673582212206b44f8a82cb6b156bfcc3dc6aadd6df4eefd204bc928a4397fd15dacf6d5320564736f6c634300060200331b83247000822470");
      console.log(receipt);
      assert.equal("0xce0042B868300000d44A59004Da54A005ffdcf9f", receipt.contractAddress);
    }
    await prepareDeployer();

    const nftClone = await nft.new();
    let receipt = await web3.eth.getTransactionReceipt(nftClone.transactionHash);
    console.log(receipt);

    const contract = await nft.deployed();

    // const deployTx = deterministicDeployment(nft.bytecode, receipt.gasUsed);
    // const sender = Address.fromPublicKey(deployTx.getSenderPublicKey());
    // console.log(sender.toString());
    // const sendethTx = {
    //   from: accounts[0],
    //   to: sender.toString(),
    //   value: web3.utils.toWei("1", "ether"),
    // };
    // const rtx = await web3.eth.sendTransaction(sendethTx);
    // console.log(rtx);
    // console.log(bufferToHex(deployTx.serialize()));
    // const dtx = await web3.eth.sendSignedTransaction(bufferToHex(deployTx.serialize()));
    // console.log(dtx);

    const expectedAddr = getExpectedAddress("0xce0042B868300000d44A59004Da54A005ffdcf9f", nft.bytecode, "0x000000000000000000000000000000000000000000000000000000000000beef");
    console.log(expectedAddr);

    scriptContract = contract;
    assert.equal(await contract.totalSupply.call(), 0);
    const emptyCode = new Uint8Array(1024);
    const tx = await contract.upload("", emptyCode, { from: accounts[0] });
    assert.equal(tx.logs[0].args.tokenId.toString(), "1");
    assert.equal(tx.receipt.gasUsed, 273361);
    assert.equal(await contract.totalSupply.call(), 1);
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[0]);
    const script = await contract.scriptFromId.call(tx.logs[0].args.tokenId);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal(script.scriptBytes, codeHex);
    const scriptFromHash = await contract.scriptFromHash.call(scriptHash);
    assert.equal(scriptFromHash.scriptBytes, script.scriptBytes);

    const deployerContract = new web3.eth.Contract([
      {
        "constant": false,
        "inputs": [
          {
            "internalType": "bytes",
            "name": "_initCode",
            "type": "bytes"
          },
          {
            "internalType": "bytes32",
            "name": "_salt",
            "type": "bytes32"
          }
        ],
        "name": "deploy",
        "outputs": [
          {
            "internalType": "address payable",
            "name": "createdContract",
            "type": "address"
          }
        ],
        "payable": false,
        "stateMutability": "nonpayable",
        "type": "function"
      }
    ], "0xce0042B868300000d44A59004Da54A005ffdcf9f");
    // console.log(nft.bytecode);
    const deployedTx = await deployerContract.methods.deploy(nft.bytecode, "0x000000000000000000000000000000000000000000000000000000000000beef").send({
      from: accounts[0],
      // gasPrice: "10000000000000",
      gas: receipt.gasUsed + 500000
    });
    console.log(deployedTx);

    const uniqueContract = new web3.eth.Contract(nft.abi, expectedAddr);
    const uniquedTx = await uniqueContract.methods.upload("", emptyCode).send({
      from: accounts[0],
      // gasPrice: "10000000000000",
      gas: 300000
   });
    console.log(uniquedTx);
  });

  it("should not upload a script", async () => {
    try {
      const contract = await nft.deployed();
      assert.equal(await contract.totalSupply.call(), 1);
      const emptyCode = new Uint8Array(1024);
      await contract.uploadWithEnvironment("", emptyCode, emptyCode, { from: accounts[0] });
    } catch (e) {
      assert(e.reason == "HastenScript: script hash already minted");
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
    assert.equal(tx.logs[0].args.tokenId.toString(), "2");
    assert.equal(tx.receipt.gasUsed, 318677);
    assert.equal(await contract.totalSupply.call(), 2);
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[0]);
    const script = await contract.scriptFromId.call(tx.logs[0].args.tokenId);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal(script.scriptBytes, codeHex);
    assert.equal(script.environment, codeHex);
  });

  it("should not update a script's environment", async () => {
    try {
      const contract = await nft.deployed();
      const emptyCode = new Uint8Array(30);
      await contract.update(1, emptyCode, { from: accounts[1] });
    } catch (e) {
      assert(e.reason == "Only the owner of the script can update its environment");
      return;
    }
    assert(false, "expected exception not thrown");
  });

  it("should update a script's environment", async () => {
    const contract = await nft.deployed();
    const emptyCode = new Uint8Array(30);
    await contract.update(1, emptyCode, { from: accounts[0] });
    const script = await contract.scriptFromHash.call(scriptHash);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal(script.environment, codeHex);
  });

  it("should upload a mod", async () => {
    await nft.deployed();
    const dao20 = await dao.deployed();
    const contract = await modNft.deployed();
    assert.equal(await dao20.balanceOf.call(contract.address), web3.utils.toWei("1024", "ether"));
    const empty = new Uint8Array(1024);
    const tx = await contract.upload("", 1, empty, { from: accounts[0] });
    assert.equal(tx.logs[0].args.tokenId.toString(), 1);
    assert.equal(tx.receipt.gasUsed, 275206);
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
      const tx = await contract.upload("", 1, empty, { from: accounts[1] });
      assert.equal(tx.logs[0].args.tokenId.toString(), 1);
      assert.equal(tx.receipt.gasUsed, 275451);
      assert.equal(await contract.totalSupply.call(), 1);
      assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[1]);
      const script = await contract.scriptFromId.call(tx.logs[0].args.tokenId);
      const codeHex = web3.utils.bytesToHex(empty);
      assert.equal(script.scriptBytes, codeHex);
    } catch (e) {
      assert(e.reason == "HastenMod: Only the owner of the script can upload mods");
      return;
    }
    assert(false, "expected exception not thrown");
  });

  it("should upload a mod with delegate", async () => {
    const empty = new Uint8Array(1024);
    const parts = [
      { t: "address", v: accounts[1] },
      { t: "string", v: "" },
      { t: "uint256", v: 1 },
      { t: "bytes", v: web3.utils.bytesToHex(empty) }
    ];
    const messageHex = web3.utils.soliditySha3(...parts);
    const signature = await signMessage(accounts[2], messageHex);
    await nft.deployed();
    const dao20 = await dao.deployed();
    const contract = await modNft.deployed();
    await contract.setDelegate(1, accounts[2], { from: accounts[0] });
    const tx = await contract.uploadWithDelegateAuth(signature, "", 1, empty, { from: accounts[1] });
    assert.equal(tx.logs[0].args.tokenId.toString(), 2);
    assert.equal(tx.receipt.gasUsed, 236239);
    assert.equal(await contract.totalSupply.call(), 2);
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[1]);
    const script = await contract.script.call(tx.logs[0].args.tokenId);
    const codeHex = web3.utils.bytesToHex(empty);
    assert.equal(script.scriptBytes, codeHex);
    // mint - no rewards
    assert.equal(await dao20.balanceOf.call(contract.address), web3.utils.toWei("1023990", "milli"));
  });

  it("should not upload a mod with delegate", async () => {
    try {
      const empty = new Uint8Array(1024);
      const parts = [
        { t: "address", v: accounts[1] },
        { t: "string", v: "" },
        { t: "uint256", v: 1 },
        { t: "bytes", v: web3.utils.bytesToHex(empty) }
      ];
      const messageHex = web3.utils.soliditySha3(...parts);
      const signature = await signMessage(accounts[3], messageHex);
      await nft.deployed();
      const dao20 = await dao.deployed();
      const contract = await modNft.deployed();
      await contract.setDelegate(1, accounts[2], { from: accounts[0] });
      const tx = await contract.uploadWithDelegateAuth(signature, "", 1, empty, { from: accounts[1] });
    } catch (e) {
      assert(e.reason == "HastenMod: Invalid signature");
      return;
    }
    assert(false, "expected exception not thrown");
  });
});
