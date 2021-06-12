const { Address, bufferToHex } = require("ethereumjs-util");
const { Transaction } = require("@ethereumjs/tx");
const { keccak256, hexToBytes, bytesToHex } = require("web3-utils");
const { BN } = require("bn.js");

var nft = artifacts.require("FragmentTemplate");
var entityNft = artifacts.require("FragmentEntity");
var dao = artifacts.require("FragmentDAOToken");

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
  // console.log(composeCall(contractBytes, "0x711"));
  const deployTx = new Transaction({
    nonce: 0,
    gasPrice: new BN(web3.utils.toWei("500", "gwei"), 10),
    gasLimit: 247000,
    value: 0,
    data: "0x608060405234801561001057600080fd5b50610134806100206000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80634af63f0214602d575b600080fd5b60cf60048036036040811015604157600080fd5b810190602081018135640100000000811115605b57600080fd5b820183602082011115606c57600080fd5b80359060200191846001830284011164010000000083111715608d57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250929550509135925060eb915050565b604080516001600160a01b039092168252519081900360200190f35b6000818351602085016000f5939250505056fea26469706673582212206b44f8a82cb6b156bfcc3dc6aadd6df4eefd204bc928a4397fd15dacf6d5320564736f6c63430006020033",
    v: 27,
    r: "0x247000",
    s: "0x2470"
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

contract("FragmentTemplate", accounts => {
  var tokenOne = null;

  it("should upload a template", async () => {
    const params = {
      from: accounts[0],
      to: "0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974",
      value: web3.utils.toWei("1", "ether"),
    };
    await web3.eth.sendTransaction(params);
    const dao20 = await dao.deployed();

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

    await contract.setDAOToken(dao20.address, { from: "0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974" });
    await contract.setRewardAllocation(web3.utils.toWei("1", "ether"), { from: "0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974" });

    const deployTx = deterministicDeployment(nft.bytecode, receipt.gasUsed);
    const sender = Address.fromPublicKey(deployTx.getSenderPublicKey());
    console.log(sender.toString());
    // const sendethTx = {
    //   from: accounts[0],
    //   to: sender.toString(),
    //   value: web3.utils.toWei("1", "ether"),
    // };
    // const rtx = await web3.eth.sendTransaction(sendethTx);
    // console.log(rtx);
    console.log(bufferToHex(deployTx.serialize()));
    // const dtx = await web3.eth.sendSignedTransaction(bufferToHex(deployTx.serialize()));
    // console.log(dtx);

    const expectedAddr = getExpectedAddress("0xce0042B868300000d44A59004Da54A005ffdcf9f", nft.bytecode, "0xce1e2eeb9663dbc0d7622c024ae0a1a0db6a38867230eaaa67e76174dab8a19b");
    console.log(expectedAddr);

    templateContract = contract;

    const emptyCode = new Uint8Array(1024);
    const tx = await contract.upload(emptyCode, emptyCode, [], [], [], 0, { from: accounts[0] });
    console.log("Mint tx", tx);
    const hexHashId = web3.utils.numberToHex(tx.logs[0].args.tokenId);
    const emptyCodeHash = "0x" + keccak256(emptyCode).slice(27);
    assert.equal(hexHashId, emptyCodeHash);
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[0]);
    tokenOne = emptyCodeHash;
    const template = await contract.dataOf.call(tx.logs[0].args.tokenId);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    // slice 0x01
    assert.equal("0x" + template.immutableData.slice(4), codeHex);

    try {
      const uri = await contract.tokenURI.call(tx.logs[0].args.tokenId);
      assert.equal(uri, "https://meta.fragcolor.xyz/2miLKyaattHF4mnXdZ2Gr2Zu7Ty");
    } catch (err) {
      console.log(err);
      throw err;
    }

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
    const deployedTx = await deployerContract.methods.deploy(nft.bytecode, "0xce1e2eeb9663dbc0d7622c024ae0a1a0db6a38867230eaaa67e76174dab8a19b").send({
      from: accounts[0],
      // gasPrice: "10000000000000",
      gas: receipt.gasUsed + 500000
    });
    console.log(deployedTx);

    const uniqueContract = new web3.eth.Contract(nft.abi, expectedAddr);
    const uniquedTx = await uniqueContract.methods.upload(emptyCode, emptyCode, [], [], [], 0).send({
      from: accounts[0],
      // gasPrice: "10000000000000",
      gas: 300000
    });
    console.log(uniquedTx);
  });

  it("should not upload a template", async () => {
    try {
      const contract = await nft.deployed();
      const emptyCode = new Uint8Array(1024);
      await contract.upload(emptyCode, emptyCode, [], [], [], 0, { from: accounts[0] });
    } catch (e) {
      assert(e.reason == "FragmentTemplate: template already minted", e);
      return;
    }
    assert(false, "expected exception not thrown");
  });

  it("should upload a template with environment", async () => {
    const contract = await nft.deployed();
    const emptyCode = new Uint8Array(1024);
    emptyCode[0] = 1; // make a small change in order to succeed
    const tx = await contract.upload(emptyCode, emptyCode, [], [], [], 0, { from: accounts[1] });
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[1]);
    const template = await contract.dataOf.call(tx.logs[0].args.tokenId);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal("0x" + template.immutableData.slice(4), codeHex);
    assert.equal("0x" + template.mutableData.slice(4), codeHex);
    const dao20 = await dao.deployed();
    assert.equal(await dao20.balanceOf.call(accounts[1]), web3.utils.toWei("10", "milli"));
  });

  it("should not update a template's environment", async () => {
    try {
      const contract = await nft.deployed();
      const emptyCode = new Uint8Array(30);
      await contract.update(tokenOne, emptyCode, 0, { from: accounts[1] });
    } catch (e) {
      assert(e.reason == "FragmentTemplate: only the owner of the template can update it");
      return;
    }
    assert(false, "expected exception not thrown");
  });

  it("should update a template's environment", async () => {
    const contract = await nft.deployed();
    const emptyCode = new Uint8Array(30);
    await contract.update(tokenOne, emptyCode, 10, { from: accounts[0] });
    const template = await contract.dataOf.call(tokenOne);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal("0x" + template.mutableData.slice(4), codeHex);
    const includeCost = await contract.includeCostOf.call(tokenOne);
    assert.equal(10, includeCost.toNumber());
  });

  it("should upload a template with reference, paying referenced", async () => {
    const contract = await nft.deployed();
    const dao20 = await dao.deployed();
    // disable rewards, testing that too
    await contract.setMintReward(0, { from: "0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974" });
    const emptyCode = new Uint8Array(1024);
    const initialBalance = await dao20.balanceOf.call(accounts[1]);
    await dao20.approve(contract.address, 10, { from: accounts[1] });
    await contract.stake(tokenOne, 10, { from: accounts[1] });
    const staked = await contract.getStakers.call(tokenOne);
    assert(new BN(10, 10).eq(staked.amounts[0]));
    emptyCode[0] = 1; // make a small change in order to succeed
    const tx = await contract.upload(emptyCode, emptyCode, [tokenOne], [], [], 0, { from: accounts[1] });
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[1]);
    const template = await contract.dataOf.call(tx.logs[0].args.tokenId);
    const codeHex = web3.utils.bytesToHex(emptyCode);
    assert.equal("0x" + template.immutableData.slice(4), codeHex);
    assert.equal("0x" + template.mutableData.slice(4), codeHex);
    const finalBalance = await dao20.balanceOf.call(accounts[1]);
    assert(initialBalance.sub(new BN(10, 10)).eq(finalBalance));
  });

  it("should not upload a template with reference, paying referenced", async () => {
    try {
      const contract = await nft.deployed();
      const dao20 = await dao.deployed();
      // disable rewards, testing that too
      await contract.setMintReward(0, { from: "0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974" });
      const emptyCode = new Uint8Array(1024);
      emptyCode[0] = 2; // make a small change in order to succeed
      await contract.upload(emptyCode, emptyCode, [tokenOne], [], [], 0, { from: accounts[2] });
    } catch (e) {
      assert(e.reason == "FragmentTemplate: not enough staked amount to reference template");
      return;
    }
    assert(false, "expected exception not thrown");
  });

  // it("should upload a entity", async () => {
  //   await nft.deployed();
  //   const dao20 = await dao.deployed();
  //   const contract = await entityNft.deployed();
  //   assert.equal(await dao20.balanceOf.call(contract.address), web3.utils.toWei("1024", "ether"));
  //   const empty = new Uint8Array(1024);
  //   const tx = await contract.upload(tokenOne, "0x9f668b20cfd24cdbf9e1980fa4867d08c67d2caf8499e6df81b9bf0b1c97287d", empty, 1, { from: accounts[0] });
  //   assert.equal(tx.logs[0].args.tokenId.toString(), 1);
  //   assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[0]);
  //   const template = await contract.dataOf.call(tx.logs[0].args.tokenId);
  //   const codeHex = web3.utils.bytesToHex(empty);
  //   assert.equal("0x" + template.immutableData.slice(52), codeHex);
  //   assert.equal("0x" + template.mutableData.slice(68 + 40), codeHex);
  //   // mint should not trigger rewards
  //   assert.equal(await dao20.balanceOf.call(contract.address), web3.utils.toWei("1024", "ether"));
  // });

  // it("should transfer a entity", async () => {
  //   await nft.deployed();
  //   const dao20 = await dao.deployed();
  //   const contract = await entityNft.deployed();
  //   await contract.safeTransferFrom(accounts[0], accounts[1], 1);
  //   assert.equal(await contract.ownerOf.call(1), accounts[1]);
  //   // check reward
  //   assert.equal(await dao20.balanceOf.call(contract.address), web3.utils.toWei("1023990", "milli"));
  // });

  // it("should not upload a entity", async () => {
  //   try {
  //     await nft.deployed();
  //     await dao.deployed();
  //     const contract = await entityNft.deployed();
  //     const empty = new Uint8Array(1024);
  //     await contract.upload(tokenOne, "0x9f668b20cfd24cdbf9e1980fa4867d08c67d2caf8499e6df81b9bf0b1c97287d", empty, 1, { from: accounts[1] });
  //   } catch (e) {
  //     assert(e.reason == "FragmentEntity: Only the owner of the template can upload entitys");
  //     return;
  //   }
  //   assert(false, "expected exception not thrown");
  // });

  // it("should upload a entity with delegate", async () => {
  //   const empty = new Uint8Array(1024);
  //   const parts = [
  //     { t: "address", v: accounts[1] },
  //     { t: "uint256", v: "0x1" },
  //     { t: "uint160", v: tokenOne },
  //     { t: "bytes32", v: "0x9f668b20cfd24cdbf9e1980fa4867d08c67d2caf8499e6df81b9bf0b1c97287d" },
  //     { t: "bytes", v: web3.utils.bytesToHex(empty) },
  //     { t: "uint256", v: "2" },
  //   ];
  //   const messageHex = web3.utils.soliditySha3(...parts);
  //   const signature = await signMessage(accounts[2], messageHex);
  //   await nft.deployed();
  //   const dao20 = await dao.deployed();
  //   const contract = await entityNft.deployed();
  //   await contract.setDelegate(tokenOne, accounts[2], { from: accounts[0] });
  //   const tx = await contract.uploadWithDelegateAuth(signature, tokenOne, "0x9f668b20cfd24cdbf9e1980fa4867d08c67d2caf8499e6df81b9bf0b1c97287d", empty, 2, { from: accounts[1] });
  //   {
  //     assert.equal(tx.logs[0].args.tokenId.toString(), 2);
  //     assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[1]);
  //     const template = await contract.dataOf.call(tx.logs[0].args.tokenId);
  //     const codeHex = web3.utils.bytesToHex(empty);
  //     assert.equal("0x" + template.immutableData.slice(52), codeHex);
  //     assert.equal("0x" + template.mutableData.slice(68 + 40), codeHex);
  //   }
  //   {
  //     assert.equal(tx.logs[1].args.tokenId.toString(), 3);
  //     assert.equal(await contract.ownerOf.call(tx.logs[1].args.tokenId), accounts[1]);
  //     const template = await contract.dataOf.call(tx.logs[1].args.tokenId);
  //     const codeHex = web3.utils.bytesToHex(empty);
  //     assert.equal("0x" + template.immutableData.slice(52), codeHex);
  //     assert.equal("0x" + template.mutableData.slice(68 + 40), codeHex);
  //   }
  //   // mint - no rewards
  //   assert.equal(await dao20.balanceOf.call(contract.address), web3.utils.toWei("1023990", "milli"));
  // });

  // it("should not upload a entity with delegate", async () => {
  //   try {
  //     const empty = new Uint8Array(1024);
  //     const parts = [
  //       { t: "address", v: accounts[1] },
  //       { t: "uint256", v: "0x1" },
  //       { t: "uint160", v: tokenOne },
  //       { t: "string", v: "0x9f668b20cfd24cdbf9e1980fa4867d08c67d2caf8499e6df81b9bf0b1c97287d" },
  //       { t: "bytes", v: web3.utils.bytesToHex(empty) },
  //       { t: "uint256", v: "1" },
  //     ];
  //     const messageHex = web3.utils.soliditySha3(...parts);
  //     const signature = await signMessage(accounts[3], messageHex);
  //     await nft.deployed();
  //     await dao.deployed();
  //     const contract = await entityNft.deployed();
  //     await contract.setDelegate(tokenOne, accounts[2], { from: accounts[0] });
  //     await contract.uploadWithDelegateAuth(signature, tokenOne, "0x9f668b20cfd24cdbf9e1980fa4867d08c67d2caf8499e6df81b9bf0b1c97287d", empty, 1, { from: accounts[1] });
  //   } catch (e) {
  //     assert(e.reason == "FragmentEntity: Invalid signature", e);
  //     return;
  //   }
  //   assert(false, "expected exception not thrown");
  // });
});
