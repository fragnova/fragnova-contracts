var vault = artifacts.require("Vault");
var fragToken = artifacts.require("FRAGToken");
var utility = artifacts.require("Utility");
const truffleAssert = require('truffle-assertions');
const ethSignUtil = require('@metamask/eth-sig-util');

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

function eip712_message_unlock(chainId, parts, contract) {
  const typedDataUnlock = {
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
      ]
    }, 
  };
    return typedDataUnlock;
};

contract("FRAGToken", (accounts) => {

  it("should be able to lock", async () => {
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
    const chainId = await web3.eth.getChainId();
    const contract = await fragToken.deployed();
    const parts = [
      { t: "name", v: "FragLock" },
      { t: "sender", v: account },
      { t: "amount", v: 1000 },
      { t: "lock_period", v: 0 },
    ];
    const parts_unlock = [
      { t: "name", v: "FragUnlock" },
      { t: "sender", v: account },
      { t: "amount", v: 0 },
    ];

    const typedData = eip712_message(chainId, parts, contract.address);
    const private_key = new Buffer.from("4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d", 'hex');
    const signature = ethSignUtil.signTypedData({privateKey: private_key, data: typedData, version: ethSignUtil.SignTypedDataVersion.V4});
    const result = await contract.lock(signature, parts[2].v, parts[3].v, { from: account });
    truffleAssert.eventEmitted(result, 'Lock');

    const typedDataUnlock = eip712_message_unlock(chainId, parts_unlock, contract.address);
    const signature_unlock = ethSignUtil.signTypedData({privateKey: private_key, data: typedDataUnlock, version: ethSignUtil.SignTypedDataVersion.V4});
    await truffleAssert.reverts(
      contract.unlock(signature_unlock, { from: account }),
      "Nothing available to unlock."
    );
  });

  it("should fail when lock period not valid", async () => {
    const contract = await fragToken.deployed();
    await contract.transfer(accounts[0], 2000);
    const chainId = await web3.eth.getChainId();

    const parts = [
      { t: "string", v: "FragLock" },
      { t: "address", v: accounts[0] },
      { t: "uint256", v: 1000 },
      { t: "uint8", v: 0 },
    ];
    await contract.transfer(accounts[0], 2000);
    const typedData = eip712_message(chainId, parts, contract.address);
    const private_key = new Buffer.from("4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d", 'hex');
    const signature = ethSignUtil.signTypedData({privateKey: private_key, data: typedData, version: ethSignUtil.SignTypedDataVersion.V4});

    await truffleAssert.reverts(
      contract.lock(signature, 100, 5, { from: accounts[0] }),
      "Time lock period not allowed"
    );
  });
});
