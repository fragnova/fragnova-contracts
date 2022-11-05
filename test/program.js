var nft = artifacts.require("Fragment");
var entityNft = artifacts.require("Entity");
var vault = artifacts.require("Vault");
var fragToken = artifacts.require("FRAGToken");
var utility = artifacts.require("Utility");
var pre721 = artifacts.require("PreERC721");
var pre721Factory = artifacts.require("PreERC721Factory");
var pre721Genesis = artifacts.require("PreERC721Genesis");
const truffleAssert = require('truffle-assertions');
const eip712 = require('eip-712');
const ethSignUtil = require('@metamask/eth-sig-util');
const ethUtils = require('ethereumjs-util');
const bip39 = require('bip39');
const hdkey = require('@truffle/hdwallet-provider');
const wallet = require('ethereumjs-wallet');

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

function eip712_message(chainId, parts, contract) {
  const typedData = {
    domain: {
      name: 'Fragnova Network Token',
      version: '1',
      chainId: chainId,
      verifyingContract: contract
    },
    message: {
      name: parts[0].v,
      sender: parts[1].v,
      amount: parts[2].v,
      lock_period: parts[3].v
    },
    primaryType:'Msg',
    types: {
      EIP712Domain: [
        {type:'string', name: 'name'},
        {type:'string', name: 'version'},
        {type:'uint256', name: 'chainId'},
        {type:'address', name: 'verifyingContract'}
      ],
      Msg:[
        {type: "string", name: "name"},
        {type: "address", name: "sender"},
        {type: "uint256", name: "amount"},
        {type: "uint8", name: "lock_period"}
      ]
    }, 
  };
    return typedData;
};

contract("Fragment", (accounts) => {

  it("should upload a fragment", async () => {
    const params = {
      from: accounts[0],
      to: "0x0123456789012345678901234567890123456789",
      value: web3.utils.toWei("1", "ether"),
    };
    await web3.eth.sendTransaction(params);
    const fragToken20 = await fragToken.deployed();

    const nftClone = await nft.new();
    let receipt = await web3.eth.getTransactionReceipt(nftClone.transactionHash);
    console.log(receipt);

    const contract = await nft.deployed();
    const entityContract = await entityNft.deployed();
    const vaultContract = await vault.deployed();

    await contract.setAddress(web3.utils.sha3("fragcolor.fragment.utilityToken"), fragToken20.address, { from: "0x0123456789012345678901234567890123456789" });
    await contract.setAddress(web3.utils.sha3("fragcolor.fragment.entityLogic"), entityContract.address, { from: "0x0123456789012345678901234567890123456789" });
    await contract.setAddress(web3.utils.sha3("fragcolor.fragment.vaultLogic"), vaultContract.address, { from: "0x0123456789012345678901234567890123456789" });
    await contract.setAddress(web3.utils.sha3("fragcolor.fragment.utilityLibrary"), utility.address, { from: "0x0123456789012345678901234567890123456789" });

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
  });

});

contract("FRAGToken", (accounts) => {

  it("should be able to lock", async () => {
    //await web3.eth.accounts.wallet.create(1); // create 3 accounts
    const firstAccount = accounts[0];
    const chainId = await web3.eth.getChainId();
    const contract = await fragToken.deployed();
    const parts = [
      { t: "name", v: "FragLock" },
      { t: "sender", v: firstAccount },
      { t: "amount", v: 1000 },
      { t: "lock_period", v: 0 },
    ];
    
    await contract.transfer(firstAccount, 2000);
    const typedData = eip712_message(chainId, parts, contract.address);
    const private_key = new Buffer.from("4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d", 'hex');
    const signature = ethSignUtil.signTypedData({privateKey: private_key, data: typedData, version: ethSignUtil.SignTypedDataVersion.V4});
    const result = await contract.lock(signature, parts[2].v, parts[3].v, { from: firstAccount });
    truffleAssert.eventEmitted(result, 'Lock');
  });

  it("should be unable to unlock if still timelocked", async () => {
    const account = accounts[0];
    const fragToken20 = await fragToken.deployed();
    const chainId = await web3.eth.getChainId();
    const contract = await fragToken.deployed();
    const parts = [
      { t: "name", v: "FragLock" },
      { t: "sender", v: account },
      { t: "amount", v: 1000 },
      { t: "lock_period", v: 0 },
    ];

    const typedData = eip712_message(chainId, parts, contract.address);
    const private_key = new Buffer.from("4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d", 'hex');
    const signature = ethSignUtil.signTypedData({privateKey: private_key, data: typedData, version: ethSignUtil.SignTypedDataVersion.V4});
    const result = await contract.lock(signature, parts[2].v, parts[3].v, { from: account });
    truffleAssert.eventEmitted(result, 'Lock');

    const parts_unlock = [
      { t: "string", v: "FragLock" },
      { t: "address", v: accounts[1] },
      { t: "uint256", v: 5 },
      { t: "uint256", v: 1000 },
    ];
    const messageHex_unlock = web3.utils.soliditySha3(...parts_unlock);
    const signature_unlock = await signMessage(accounts[1], messageHex_unlock);

    await truffleAssert.reverts(
      fragToken20.unlock(signature_unlock, { from: accounts[1] }),
      "Timelock didn't expire"
    );

    var timeLock = await fragToken20.getTimeLock({ from: accounts[1] });

    var date = new Date(timeLock * 1000).getTime(); // convert to Javascript date from UNIX timestamp
    var today = new Date().getTime();
    var one_day = 1000 * 60 * 60 * 24; // one day in millisecond
    assert(14 == Math.round((date - today)/one_day), "Lock time is two weeks");
  });

  it("should fail when lock period not valid", async () => {
    const fragToken20 = await fragToken.deployed();
    await fragToken20.transfer(accounts[1], 2000);

    const parts = [
      { t: "string", v: "FragLock" },
      { t: "address", v: accounts[1] },
      { t: "uint256", v: 5 },
      { t: "uint256", v: 1000 },
      { t: "uint8", v: 0 },
    ];
    const messageHex = web3.utils.soliditySha3(...parts);
    const signature = await signMessage(accounts[1], messageHex);

    await truffleAssert.reverts(
      fragToken20.lock(signature, 100, 5, { from: accounts[1] }),
      "Time lock period not allowed"
    );
  });
});
