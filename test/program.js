const { Address, bufferToHex } = require("ethereumjs-util");
const { Transaction } = require("@ethereumjs/tx");
const { keccak256, hexToBytes, bytesToHex } = require("web3-utils");
const { BN } = require("bn.js");
const crypto = require('crypto');

var nft = artifacts.require("Fragment");
var entityNft = artifacts.require("Entity");
var vault = artifacts.require("Vault");
var dao = artifacts.require("FragmentDAOToken");
var utility = artifacts.require("Utility");

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

function randomHexString(size) {
  if (size === 0) {
    throw new Error('Zero-length randomHexString is useless.');
  }

  if (size % 2 !== 0) {
    throw new Error('randomHexString size must be divisible by 2.');
  }

  return (0, crypto.randomBytes)(size / 2).toString('hex');
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

const delay = ms => new Promise(resolve => setTimeout(resolve, ms))

contract("Fragment", accounts => {
  var tokenOne = null;
  var tokenTwo = null;

  it("should upload a fragment", async () => {
    console.log("About to await 5 seconds");
    await delay(5000);

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
    const entityContract = await entityNft.deployed();
    const vaultContract = await vault.deployed();

    await contract.setAddress(web3.utils.sha3("fragcolor.fragment.utilityToken"), dao20.address, { from: "0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974" });
    await contract.setAddress(web3.utils.sha3("fragcolor.fragment.entityLogic"), entityContract.address, { from: "0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974" });
    await contract.setAddress(web3.utils.sha3("fragcolor.fragment.vaultLogic"), vaultContract.address, { from: "0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974" });
    await contract.setAddress(web3.utils.sha3("fragcolor.fragment.utilityLibrary"), utility.address, { from: "0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974" });
    await contract.setUint(web3.utils.sha3("fragcolor.fragment.runtimeCid"), "0x9f668b20cfd24cdbf9e1980fa4867d08c67d2caf8499e6df81b9bf0b1c97287d", { from: "0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974" });

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

    fragmentContract = contract;

    const emptyCode = new Uint8Array(1024);
    const tx = await contract.upload(emptyCode, emptyCode, [], 0, { from: accounts[0] });
    console.log("Mint tx", tx);
    const hexHashId = web3.utils.numberToHex(tx.logs[0].args.tokenId);
    const emptyCodeHash = "0x" + keccak256(emptyCode).slice(27);
    assert.equal(hexHashId, emptyCodeHash);
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[0]);
    tokenOne = emptyCodeHash;

    const supply = await contract.totalSupply.call();
    assert.equal(supply.toNumber(), 1);

    try {
      const uri = await contract.tokenURI.call(tx.logs[0].args.tokenId);
      assert.equal(uri, 'https://metadata.fragments.foundation/?ch=0x01&t=0x02310db98fdaa68efed0b2068a9bef78bd3bfd74&m=0xb5d4d1df10388bbc208778ff02310db98fdaa68efed0b2068a9bef78bd3bfd74&i=0x00&ib=0x12&mb=0x00');
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
    const uniquedTx = await uniqueContract.methods.upload(emptyCode, emptyCode, [], 0).send({
      from: accounts[0],
      // gasPrice: "10000000000000",
      gas: 300000
    });
    console.log(uniquedTx);
  });

  it("should not upload a fragment", async () => {
    try {
      const contract = await nft.deployed();
      const emptyCode = new Uint8Array(1024);
      await contract.upload(emptyCode, emptyCode, [], 0, { from: accounts[0] });
    } catch (e) {
      assert(e.reason == "Fragment: fragment already minted", e);
      return;
    }
    assert(false, "expected exception not thrown");
  });

  it("should upload a fragment with environment", async () => {
    const contract = await nft.deployed();
    const emptyCode = new Uint8Array(1024);
    emptyCode[0] = 1; // make a small change in order to succeed
    const tx = await contract.upload(emptyCode, emptyCode, [], 0, { from: accounts[1] });
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[1]);
  });

  it("should not update a fragment's environment", async () => {
    try {
      const contract = await nft.deployed();
      const emptyCode = new Uint8Array(30);
      await contract.update(tokenOne, emptyCode, 0, { from: accounts[1] });
    } catch (e) {
      assert(e.reason == "Fragment: only the owner of the fragment can execute this operation");
      return;
    }
    assert(false, "expected exception not thrown");
  });

  it("should update a fragment's environment", async () => {
    const contract = await nft.deployed();
    const emptyCode = new Uint8Array(30);
    await contract.update(tokenOne, emptyCode, 10, { from: accounts[0] });
    const includeCost = await contract.includeCostOf.call(tokenOne);
    assert.equal(10, includeCost.toNumber());
  });

  it("should upload a fragment with reference, paying referenced", async () => {
    const contract = await nft.deployed();
    const dao20 = await dao.deployed();
    await dao20.transfer(accounts[1], web3.utils.toWei("1024", "ether"));
    const emptyCode = new Uint8Array(1024);
    const initialBalance = await dao20.balanceOf.call(accounts[1]);
    await dao20.approve(contract.address, 10, { from: accounts[1] });
    await contract.stake(tokenOne, 10, { from: accounts[1] });
    const count = await contract.getStakeCount.call(tokenOne);
    assert(new BN(1, 1).eq(count));
    const staked = await contract.getStakeAt.call(tokenOne, 0);
    assert(new BN(10, 10).eq(staked.amount));
    emptyCode[0] = 1; // make a small change in order to succeed
    const tx = await contract.upload(emptyCode, emptyCode, [tokenOne], 0, { from: accounts[1] });
    assert.equal(await contract.ownerOf.call(tx.logs[0].args.tokenId), accounts[1]);
    const finalBalance = await dao20.balanceOf.call(accounts[1]);
    assert(initialBalance.sub(new BN(10, 10)).eq(finalBalance));
    tokenTwo = tx.logs[0].args.tokenId.toString();
    var snapshot = await contract.getSnapshot(tokenOne, tokenTwo);
    assert.equal(snapshot, "0x000000000000000000000000000000000000000000000000000000000000000af548e71c32522ed78c2588df2cfdc3acd5c04cf930953ecabcc86ee3532f317c00000000000000120000000000000018");
    snapshot = await contract.getSnapshot(tokenTwo, tokenOne);
    assert.equal(snapshot, "0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    const descendants = await contract.descendants(tokenOne);
    assert.equal(descendants.length, 1);
  });

  it("should not upload a fragment with reference, paying referenced", async () => {
    try {
      const contract = await nft.deployed();
      await dao.deployed();
      const emptyCode = new Uint8Array(1024);
      emptyCode[0] = 2; // make a small change in order to succeed
      await contract.upload(emptyCode, emptyCode, [tokenOne], 0, { from: accounts[2] });
    } catch (e) {
      assert(e.reason == "Fragment: not enough staked amount to reference fragment");
      return;
    }
    assert(false, "expected exception not thrown");
  });

  // it("should not transfer a fragment", async () => {
  //   try {
  //     const contract = await nft.deployed();
  //     await contract.safeTransferFrom(accounts[0], accounts[1], tokenOne);
  //   } catch (e) {
  //     assert(e.reason == "Fragment: cannot transfer fragments");
  //     return;
  //   }
  //   assert(false, "expected exception not thrown");
  // });

  var fragmentOneEntity = null;

  it("should rez a entity from fragment", async () => {
    const contract = await nft.deployed();
    const tx = await contract.rez(tokenTwo, "Token Two", "TWO", false, false, 10, { from: accounts[1] });
    console.log(tx);
    fragmentOneEntity = tx.logs[0].args.entityContract;
    const entity = new web3.eth.Contract(entityNft.abi, fragmentOneEntity);
    const fragment = await entity.methods.getFragment().call();
    assert.equal(fragment, tokenTwo);
    const library = await entity.methods.getLibrary().call();
    assert.equal(library, nft.address);

    const secondaryFeesSupport = await entity.methods.supportsInterface("0xb7799584").call();
    assert(secondaryFeesSupport);
  });

  it("should not rez a entity from fragment", async () => {
    const contract = await nft.deployed();
    // this one already exists at this point
    try {
      await contract.rez(tokenTwo, "Token Two", "TWO", true, false, 10, { from: accounts[1] });
    } catch (e) {
      assert(e.reason == "Create2: Failed on deploy");
      return;
    }
    assert(false, "expected exception not thrown");
  });

  it("should mint an NFT from entity as owner", async () => {
    const entity = new web3.eth.Contract(entityNft.abi, fragmentOneEntity);
    const empty = new Uint8Array(1024);

    await entity.methods
      .setPublicSale(web3.utils.toWei("0.1", "ether"), 1, 2)
      .send({ from: accounts[1], gas: 500000 });

    await entity.methods
      .setDelegate(accounts[3])
      .send({ from: accounts[1], gas: 500000 });

    const tx = await entity.methods
      .upload(empty, 1)
      .send({ from: accounts[1], gas: 500000 });
  });

  it("should mint one from entity as buyer", async () => {
    const contract = await nft.deployed();
    const entity = new web3.eth.Contract(entityNft.abi, fragmentOneEntity);
    const empty = new Uint8Array(1024);
    const parts = [
      { t: "address", v: accounts[4] },
      { t: "uint256", v: "0x1" },
      { t: "uint160", v: tokenTwo },
      { t: "bytes", v: web3.utils.bytesToHex(empty) },
      { t: "uint96", v: "1" },
    ];
    const messageHex = web3.utils.soliditySha3(...parts);
    const signature = await signMessage(accounts[3], messageHex);
    const tx = await entity.methods
      .mint(signature, empty, 1)
      .send({ from: accounts[4], gas: 800000, value: web3.utils.toWei("0.1", "ether") });
    const res = await entity.methods.tokenURI(2).call();
    console.log(res);
    assert.equal(res, 'https://metadata.fragments.foundation/?ch=0x01&id=0x02&e=' + fragmentOneEntity.toLowerCase() + '&m=0xfa321bd82f92ef059c267763b69b7c27d6c70bd1ea86b94194ff74884fdd1ae0&d=0x23');
  });
});
