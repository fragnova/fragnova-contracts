var fragToken = artifacts.require("FRAGToken");
const truffleAssert = require('truffle-assertions');
const ethSignUtil = require('@metamask/eth-sig-util');
const { time } = require("@openzeppelin/test-helpers");

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
      min_locktime: parts[3].v,
      max_locktime: parts[4].v,
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
        {type: "uint256", name: "min_locktime"},
        {type: "uint256", name: "max_locktime"}
      ]
    }, 
  };
    return typedDataUnlock;
};

async function getLatestBlockTimestamp() {
  　var blockTimestamp = await time.latest();
    var date = new Date(blockTimestamp * 1000);
    date = date.setDate(date.getDate() + 14);
    date = date/1000;

    return date;
}

contract("FRAGToken", (accounts) => {

  beforeEach(async function () {
    await time.advanceBlock();
  });

  var locktimestamp1 = 0;
  var locktimestamp2 = 0;
  var locktimestamp3 = 0;
  var locktimestamp4 = 0;

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

    var date = await getLatestBlockTimestamp();
    locktimestamp1 = date;

    const result = await contract.lock(signature, parts[2].v, parts[3].v, { from: firstAccount });
    truffleAssert.eventEmitted(result, 'Lock');
  });

  it("should be not able to lock with wrong inputs", async () => {
    const firstAccount = accounts[0];
    const chainId = await web3.eth.getChainId();
    const contract = await fragToken.deployed();
    const parts = [
      { t: "name", v: "FragLock" },
      { t: "sender", v: firstAccount },
      { t: "amount", v: 0 },
      { t: "lock_period", v: 0 },
    ];
    
    await contract.transfer(firstAccount, 2000);
    const typedData = eip712_message(chainId, parts, contract.address);
    const private_key = new Buffer.from("4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d", 'hex');
    const signature = ethSignUtil.signTypedData({privateKey: private_key, data: typedData, version: ethSignUtil.SignTypedDataVersion.V4});
    await truffleAssert.reverts(
      contract.lock(signature, parts[2].v, parts[3].v, { from: firstAccount }),
      "Amount must be greater than 0"
    );

    const parts2 = [
      { t: "name", v: "FragLock" },
      { t: "sender", v: firstAccount },
      { t: "amount", v: 1000 },
      { t: "lock_period", v: 5 },
    ];
    const typedData2 = eip712_message(chainId, parts2, contract.address);
    const signature2 = ethSignUtil.signTypedData({privateKey: private_key, data: typedData2, version: ethSignUtil.SignTypedDataVersion.V4});
    await truffleAssert.reverts(
      contract.lock(signature2, parts2[2].v, parts2[3].v, { from: firstAccount }),
      "Time lock period not allowed"
    );
  });

  it("should be unable to unlock if still timelocked", async () => {
    const account = accounts[0];
    const chainId = await web3.eth.getChainId();
    const contract = await fragToken.deployed();
    const parts = [
      { t: "name", v: "FragLock" },
      { t: "sender", v: account },
      { t: "amount", v: 500 },
      { t: "lock_period", v: 0 },
    ];

    var date = await getLatestBlockTimestamp();
    locktimestamp2 = date;

    const parts_unlock = [
      { t: "name", v: "FragUnlock" },
      { t: "sender", v: account },
      { t: "amount", v: 0 },
      { t: "min_locktime", v: locktimestamp2 },
      { t: "max_locktime", v: locktimestamp2 },
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
      "All tokens are still not possible to unlock"
    );
  });

  it("should be able to unlock the correct amount after lock period is over", async () => {
    const account = accounts[0];
    const chainId = await web3.eth.getChainId();
    const contract = await fragToken.deployed();
    const parts = [
      { t: "name", v: "FragLock" },
      { t: "sender", v: account },
      { t: "amount", v: 2000 },
      { t: "lock_period", v: 0 },
    ];

    var date = await getLatestBlockTimestamp();
    locktimestamp3 = date;

    const parts_unlock = [
      { t: "name", v: "FragUnlock" },
      { t: "sender", v: account },
      { t: "amount", v: 3500 }, // aggregated lock amounts from the other previous js tests are considered too (1000 + 500 + 2000)
      { t: "min_locktime", v: locktimestamp1 },
      { t: "max_locktime", v: locktimestamp3 },
    ];

    // execute a lock
    const typedData = eip712_message(chainId, parts, contract.address);
    const private_key = new Buffer.from("4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d", 'hex');
    const signature = ethSignUtil.signTypedData({privateKey: private_key, data: typedData, version: ethSignUtil.SignTypedDataVersion.V4});

    const result = await contract.lock(signature, parts[2].v, parts[3].v, { from: account });
    truffleAssert.eventEmitted(result, 'Lock');

    const typedDataUnlock = eip712_message_unlock(chainId, parts_unlock, contract.address);
    const signature_unlock = ethSignUtil.signTypedData({privateKey: private_key, data: typedDataUnlock, version: ethSignUtil.SignTypedDataVersion.V4});

    const duration = time.duration.weeks(3);
    await time.increase(duration);

    // execute an unlock. Considered that all the previous locks so far were 2 weeks, after 3 weeks the unlock will unlock ALL tokens.
    await contract.unlock(signature_unlock, { from: account });

   // execute a new lock after the unlock
    const typedData_new_lock = eip712_message(chainId, parts, contract.address);
    const signature_new_lock = ethSignUtil.signTypedData({privateKey: private_key, data: typedData_new_lock, version: ethSignUtil.SignTypedDataVersion.V4});

    var date2 = await getLatestBlockTimestamp();
    locktimestamp4 = date2;

    const result_new_lock = await contract.lock(signature_new_lock, parts[2].v, parts[3].v, { from: account });
    truffleAssert.eventEmitted(result_new_lock, 'Lock');

    await time.increase(duration);

    const parts_unlock_new = [
      { t: "name", v: "FragUnlock" },
      { t: "sender", v: account },
      { t: "amount", v: 2000 }, 
      { t: "min_locktime", v: locktimestamp4 },
      { t: "max_locktime", v: locktimestamp4 },
    ];

    // execute an unlock where there will be only the latest 1000 tokens locked.
    const typedDataUnlock_new = eip712_message_unlock(chainId, parts_unlock_new, contract.address);
    const signature_unlock_new = ethSignUtil.signTypedData({privateKey: private_key, data: typedDataUnlock_new, version: ethSignUtil.SignTypedDataVersion.V4});
    await contract.unlock(signature_unlock_new, { from: account });

  });

  it("If nothing is locked, unlock does not work", async () => {
    const account = accounts[0];
    const chainId = await web3.eth.getChainId();
    const contract = await fragToken.deployed();

    const parts_unlock_new = [
      { t: "name", v: "FragUnlock" },
      { t: "sender", v: account },
      { t: "amount", v: 0 }, // The unlock in the previous test has drained all tokens to possibly unlock
      { t: "min_locktime", v: locktimestamp1 },
      { t: "max_locktime", v: locktimestamp1 },
    ];

    // execute an unlock where there will be only the latest 1000 tokens locked.
    const typedDataUnlock_new = eip712_message_unlock(chainId, parts_unlock_new, contract.address);
    const private_key = new Buffer.from("4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d", 'hex');
    const signature_unlock_new = ethSignUtil.signTypedData({privateKey: private_key, data: typedDataUnlock_new, version: ethSignUtil.SignTypedDataVersion.V4});
    await truffleAssert.reverts(
      contract.unlock(signature_unlock_new, { from: account }),
      "There no locked tokens OR they have been all already unlocked"
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
