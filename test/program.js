// const { Address, bufferToHex, keccak256 } = require("ethereumjs-util");
// const { Transaction } = require("@ethereumjs/tx");
// const { BN } = require("bn.js");
// const crypto = require('crypto');

var nft = artifacts.require("Fragment");
var entityNft = artifacts.require("Entity");
var vault = artifacts.require("Vault");
var dao = artifacts.require("FRAGToken");
var utility = artifacts.require("Utility");
var pre721 = artifacts.require("PreERC721");
var pre721Factory = artifacts.require("PreERC721Factory");
var pre721Genesis = artifacts.require("PreERC721Genesis");

// function composeCall(bytecode, salt) {
//   return web3.eth.abi.encodeFunctionCall({
//     name: 'deploy',
//     type: 'function',
//     inputs: [{
//       type: 'bytes',
//       name: '_initCode'
//     }, {
//       type: 'bytes32',
//       name: '_salt'
//     }]
//   }, [bytecode, salt]);
// }

// function randomHexString(size) {
//   if (size === 0) {
//     throw new Error('Zero-length randomHexString is useless.');
//   }

//   if (size % 2 !== 0) {
//     throw new Error('randomHexString size must be divisible by 2.');
//   }

//   return (0, crypto.randomBytes)(size / 2).toString('hex');
// }

// function deterministicDeployment(contractBytes, gasCost) {
//   // console.log(composeCall(contractBytes, "0x711"));
//   const deployTx = new Transaction({
//     nonce: 0,
//     gasPrice: new BN(web3.utils.toWei("500", "gwei"), 10),
//     gasLimit: 247000,
//     value: 0,
//     data: "0x608060405234801561001057600080fd5b50610134806100206000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80634af63f0214602d575b600080fd5b60cf60048036036040811015604157600080fd5b810190602081018135640100000000811115605b57600080fd5b820183602082011115606c57600080fd5b80359060200191846001830284011164010000000083111715608d57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250929550509135925060eb915050565b604080516001600160a01b039092168252519081900360200190f35b6000818351602085016000f5939250505056fea26469706673582212206b44f8a82cb6b156bfcc3dc6aadd6df4eefd204bc928a4397fd15dacf6d5320564736f6c63430006020033",
//     v: 27,
//     r: "0x247000",
//     s: "0x2470"
//   });
//   return deployTx;
// }

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

// function toEthSignedMessageHash(messageHex) {
//   const messageBuffer = Buffer.from(messageHex.substring(2), 'hex');
//   const prefix = Buffer.from(`\u0019Ethereum Signed Message:\n${messageBuffer.length}`);
//   return web3.utils.sha3(Buffer.concat([prefix, messageBuffer]));
// }

// const delay = ms => new Promise(resolve => setTimeout(resolve, ms))

contract("Fragment", accounts => {
  // var tokenOne = null;
  // var tokenTwo = null;

  it("should upload a fragment", async () => {
    // console.log("About to await 5 seconds");
    // await delay(5000);

    const params = {
      from: accounts[0],
      to: "0x0123456789012345678901234567890123456789",
      value: web3.utils.toWei("1", "ether"),
    };
    await web3.eth.sendTransaction(params);
    const dao20 = await dao.deployed();

    // const prepareDeployer = async function () {
    //   const params = {
    //     from: accounts[0],
    //     to: "0xBb6e024b9cFFACB947A71991E386681B1Cd1477D",
    //     value: web3.utils.toWei("1", "ether"),
    //   };
    //   await web3.eth.sendTransaction(params);
    //   const receipt = await web3.eth.sendSignedTransaction("0xf9016c8085174876e8008303c4d88080b90154608060405234801561001057600080fd5b50610134806100206000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80634af63f0214602d575b600080fd5b60cf60048036036040811015604157600080fd5b810190602081018135640100000000811115605b57600080fd5b820183602082011115606c57600080fd5b80359060200191846001830284011164010000000083111715608d57600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250929550509135925060eb915050565b604080516001600160a01b039092168252519081900360200190f35b6000818351602085016000f5939250505056fea26469706673582212206b44f8a82cb6b156bfcc3dc6aadd6df4eefd204bc928a4397fd15dacf6d5320564736f6c634300060200331b83247000822470");
    //   console.log(receipt);
    //   assert.equal("0xce0042B868300000d44A59004Da54A005ffdcf9f", receipt.contractAddress);
    // }
    // await prepareDeployer();

    const nftClone = await nft.new();
    let receipt = await web3.eth.getTransactionReceipt(nftClone.transactionHash);
    console.log(receipt);

    const contract = await nft.deployed();
    const entityContract = await entityNft.deployed();
    const vaultContract = await vault.deployed();

    await contract.setAddress(web3.utils.sha3("fragcolor.fragment.utilityToken"), dao20.address, { from: "0x0123456789012345678901234567890123456789" });
    await contract.setAddress(web3.utils.sha3("fragcolor.fragment.entityLogic"), entityContract.address, { from: "0x0123456789012345678901234567890123456789" });
    await contract.setAddress(web3.utils.sha3("fragcolor.fragment.vaultLogic"), vaultContract.address, { from: "0x0123456789012345678901234567890123456789" });
    await contract.setAddress(web3.utils.sha3("fragcolor.fragment.utilityLibrary"), utility.address, { from: "0x0123456789012345678901234567890123456789" });

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

    fragmentContract = contract;

    var tx = await contract.addAuth("0x9c5fc970508a35c3ef123294b3aa105f2cbefd30", { from: "0x0123456789012345678901234567890123456789" });
    console.log("Add auth tx", tx);

    // we derive those from our Clamor substrate node test
    const fragmentHash = "0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd";
    const detachSignature = "0x3e10323c2f03effa9b5f801df36d5eb9b65f28533d494d5c06aaf1af87acd08c4ce34ebe0a42bc39cf418a1d4a8b33d10c12a58b33334c7c71579eeb46ba40471b";

    tx = await contract.attach(fragmentHash, detachSignature, { from: accounts[0] });
    console.log("Mint tx", tx);
    const id = await contract.idOf(fragmentHash);
    assert.equal(id.toNumber(), 1);

    tx = await contract.spawn(1, "TEST Entity", "TEST", true, false, 100, { from: accounts[0], gas: 1000000 });
    console.log("Mint tx", tx);
    // const hexHashId = web3.utils.numberToHex(tx.logs[0].args.tokenId);
    // const emptyCodeHash = "0x" + bufferToHex(keccak256(emptyCode)).slice(27);
    // assert.equal(hexHashId, emptyCodeHash);
    // assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[0]);
    // tokenOne = emptyCodeHash;

    // const supply = await contract.totalSupply.call();
    // assert.equal(supply.toNumber(), 1);

    // try {
    //   const uri = await contract.tokenURI.call(tx.logs[0].args.tokenId);
    //   assert.equal(uri, 'https://metadata.fragments.foundation/?ch=0x01&t=0x02310db98fdaa68efed0b2068a9bef78bd3bfd74&m=0xb5d4d1df10388bbc208778ff02310db98fdaa68efed0b2068a9bef78bd3bfd74&i=0x00&ib=0x12&mb=0x00');
    // } catch (err) {
    //   console.log(err);
    //   throw err;
    // }

    // const deployerContract = new web3.eth.Contract([
    //   {
    //     "constant": false,
    //     "inputs": [
    //       {
    //         "internalType": "bytes",
    //         "name": "_initCode",
    //         "type": "bytes"
    //       },
    //       {
    //         "internalType": "bytes32",
    //         "name": "_salt",
    //         "type": "bytes32"
    //       }
    //     ],
    //     "name": "deploy",
    //     "outputs": [
    //       {
    //         "internalType": "address payable",
    //         "name": "createdContract",
    //         "type": "address"
    //       }
    //     ],
    //     "payable": false,
    //     "stateMutability": "nonpayable",
    //     "type": "function"
    //   }
    // ], "0xce0042B868300000d44A59004Da54A005ffdcf9f");
    // // console.log(nft.bytecode);
    // const deployedTx = await deployerContract.methods.deploy(nft.bytecode, "0xce1e2eeb9663dbc0d7622c024ae0a1a0db6a38867230eaaa67e76174dab8a19b").send({
    //   from: accounts[0],
    //   // gasPrice: "10000000000000",
    //   gas: receipt.gasUsed + 500000
    // });
    // console.log(deployedTx);
  });

  it("should fail to attach using same signature again", async () => {
    const contract = await nft.deployed();

    // we derive those from our Clamor substrate node test
    const fragmentHash = "0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd";
    const detachSignature = "0x3e10323c2f03effa9b5f801df36d5eb9b65f28533d494d5c06aaf1af87acd08c4ce34ebe0a42bc39cf418a1d4a8b33d10c12a58b33334c7c71579eeb46ba40471b";

    try {
      const tx = await contract.attach(fragmentHash, detachSignature, { from: accounts[0] });
    } catch (e) {
      assert(e.message.search('Invalid signature') >= 0);
      return;
    }
    assert(false, "expected exception not thrown");
  });

  it("test airdrop NFT contract", async () => {
    const cpre721Factory = await pre721Factory.deployed();
    const cpre721Genesis = await pre721Genesis.deployed();
    console.log("Genesis contract ", cpre721Genesis.address);
    const cpre721 = await pre721.deployed();
    const fragmentHash = "0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd";

    const tx = await cpre721Factory.create(web3.utils.asciiToHex("PreERC721Sample"), web3.utils.asciiToHex("PES"), fragmentHash, "0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1", cpre721.address, { from: accounts[0] });
    console.log(tx.logs[0].args.newContract);
    const newContractAddr = tx.logs[0].args.newContract;
    const newContract = new web3.eth.Contract(cpre721.abi, newContractAddr);

    const init = await cpre721Genesis.init(newContractAddr, { from: accounts[0] });

    const txG = await newContract.methods.genesis(cpre721Genesis.address).send({ from: accounts[0], gas: 1000000 });

    assert.equal(await newContract.methods.ownerOf(1).call(), accounts[0]);
    assert.equal(await newContract.methods.ownerOf(2).call(), accounts[1]);
    assert.equal(await newContract.methods.ownerOf(3).call(), accounts[2]);
    assert.equal(await newContract.methods.ownerOf(4).call(), accounts[3]);
    assert.equal(await newContract.methods.ownerOf(5).call(), accounts[4]);
    assert.equal(await newContract.methods.ownerOf(6).call(), accounts[5]);
    assert.equal(await newContract.methods.ownerOf(7).call(), accounts[6]);
    assert.equal(await newContract.methods.ownerOf(8).call(), accounts[7]);
    assert.equal(await newContract.methods.ownerOf(9).call(), accounts[8]);
    assert.equal(await newContract.methods.ownerOf(10).call(), accounts[9]);

    assert.equal(await newContract.methods.name().call(), "PreERC721Sample\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000");
    assert.equal(await newContract.methods.symbol().call(), "PES\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000");

    assert.equal(await newContract.methods.tokenURI(2).call(), "https://gateway.server.com/0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd/metadata/0x02");
    assert.equal(await newContract.methods.contractURI().call(), 'data:application/json,{"name":"PreERC721Sample\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000\u0000","description":"","seller_fee_basis_points":700,"fee_recipient":"0x90f8bf6a479f320ead074411a4b0e7944ea8c9c1","image":"https://gateway.server.com/0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd/logo","external_link":"https://gateway.server.com/0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd/page"}');

    assert.equal(await newContract.methods.balanceOf(accounts[0]).call(), 10);
    const tx2 = await newContract.methods.transferFrom(accounts[0], accounts[2], 1).send({ from: accounts[0], gas: 500000 });
    assert.equal(await newContract.methods.ownerOf(1).call(), accounts[2]);
    assert.equal(await newContract.methods.balanceOf(accounts[2]).call(), 11);
    assert.equal(await newContract.methods.balanceOf(accounts[0]).call(), 9);

    // const owner1 = await newContract.methods.ownerOf(1).call();
    // console.log(owner1);
    // const name = await newContract.methods.name().call();
    // console.log(name);

    // assert.equal(await newContract.methods.name().call(), "Test Drop");
    // assert.equal(await newContract.methods.symbol().call(), "TEST");
    // assert.equal(await newContract.methods.tokenURI(1).call(), "https://metadata.fragments.foundation/?ch=0x01&t=0x02310db98fdaa68efed0b2068a9bef78bd3bfd74&m=0xb5d4d1df10388bbc208778ff02310db98fdaa68efed0b2068a9bef78bd3bfd74&i=0x00&ib=0x12&mb=0x00");
  });

  // it("should not upload a fragment", async () => {
  //   try {
  //     const contract = await nft.deployed();
  //     const emptyCode = new Uint8Array(1024);
  //     await contract.upload(emptyCode, emptyCode, [], 0, { from: accounts[0] });
  //   } catch (e) {
  //     assert(e.reason == "Fragment: fragment already minted", e);
  //     return;
  //   }
  //   assert(false, "expected exception not thrown");
  // });

  // it("should upload a fragment with environment", async () => {
  //   const contract = await nft.deployed();
  //   const emptyCode = new Uint8Array(1024);
  //   emptyCode[0] = 1; // make a small change in order to succeed
  //   const tx = await contract.upload(emptyCode, emptyCode, [], 0, { from: accounts[1] });
  //   assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[1]);
  // });

  // it("should not update a fragment's environment", async () => {
  //   try {
  //     const contract = await nft.deployed();
  //     const emptyCode = new Uint8Array(30);
  //     await contract.update(tokenOne, emptyCode, 0, { from: accounts[1] });
  //   } catch (e) {
  //     assert(e.reason == "Fragment: only the owner of the fragment can execute this operation");
  //     return;
  //   }
  //   assert(false, "expected exception not thrown");
  // });

  // it("should update a fragment's environment", async () => {
  //   const contract = await nft.deployed();
  //   const emptyCode = new Uint8Array(30);
  //   await contract.update(tokenOne, emptyCode, 10, { from: accounts[0] });
  //   const includeCost = await contract.includeCostOf.call(tokenOne);
  //   assert.equal(10, includeCost.toNumber());
  // });

  it("should upload a fragment with reference, paying referenced", async () => {
    const contract = await nft.deployed();

    const dao20 = await dao.deployed();
    await dao20.transfer(accounts[1], 2000);

    const parts = [
      { t: "string", v: "FragLock" },
      { t: "address", v: accounts[1] },
      { t: "uint64", v: 5 },
      { t: "uint256", v: 1000 },
    ];
    const messageHex = web3.utils.soliditySha3(...parts);
    const signature = await signMessage(accounts[1], messageHex);

    await dao20.lock(1000, signature, 0, { from: accounts[1] });
  });

  it("should be unable to unlock if still timelocked", async () => {
    const dao20 = await dao.deployed();

    const parts = [
      { t: "string", v: "FragLock" },
      { t: "address", v: accounts[1] },
      { t: "uint64", v: 5 },
      { t: "uint256", v: 1000 },
    ];
    const messageHex = web3.utils.soliditySha3(...parts);
    const signature = await signMessage(accounts[1], messageHex);

    await dao20.lock(1000, signature, 0, { from: accounts[1] });
    
    try {
      const tx = await dao20.unlock(signature, { from: accounts[1] });
    } catch (e) {
      assert(e.message.search("Lock cooldown didn't expire") >= 0);
    }

    var timeLock = await dao20.getTimeLock({ from: accounts[1] });
    var twoWeeksFromNow = new Date().getDate() + 14;
    assert(twoWeeksFromNow, timeLock, "Dates are the same")
  });

});
