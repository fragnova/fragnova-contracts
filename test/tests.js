var vault = artifacts.require("Vault");
var fragToken = artifacts.require("FRAGToken");
var utility = artifacts.require("Utility");
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
        {type: "uint256", name: "amount"}
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
    const parts_unlock = [
      { t: "name", v: "FragUnlock" },
      { t: "sender", v: account },
      { t: "amount", v: 3500 }, // aggregated lock amounts from the other previous js tests are considered too (1000 + 500 + 2000)
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
    const result_new_lock = await contract.lock(signature_new_lock, parts[2].v, parts[3].v, { from: account });
    truffleAssert.eventEmitted(result_new_lock, 'Lock');

    await time.increase(duration);

    const parts_unlock_new = [
      { t: "name", v: "FragUnlock" },
      { t: "sender", v: account },
      { t: "amount", v: 2000 }, 
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
    ];

    // execute an unlock where there will be only the latest 1000 tokens locked.
    const typedDataUnlock_new = eip712_message_unlock(chainId, parts_unlock_new, contract.address);
    const private_key = new Buffer.from("4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d", 'hex');
    const signature_unlock_new = ethSignUtil.signTypedData({privateKey: private_key, data: typedDataUnlock_new, version: ethSignUtil.SignTypedDataVersion.V4});
    await truffleAssert.reverts(
      contract.unlock(signature_unlock_new, { from: account }),
      "No previous lock executed"
    );
  });

  it("with multiple locks, should be able to unlock only the unlockable amount, leaving unlockable ones stored", async () => {
    const account = accounts[0];
    const chainId = await web3.eth.getChainId();
    const contract = await fragToken.deployed();
    const parts_two_weeks = [
      { t: "name", v: "FragLock" },
      { t: "sender", v: account },
      { t: "amount", v: 2000 },
      { t: "lock_period", v: 0 },
    ];
    const parts_three_months = [
      { t: "name", v: "FragLock" },
      { t: "sender", v: account },
      { t: "amount", v: 600 },
      { t: "lock_period", v: 2 },
    ];
    const parts_one_year = [
      { t: "name", v: "FragLock" },
      { t: "sender", v: account },
      { t: "amount", v: 5000 },
      { t: "lock_period", v: 4 },
    ];
    const parts_unlock = [
      { t: "name", v: "FragUnlock" },
      { t: "sender", v: account },
      { t: "amount", v: 2000 }, // aggregated lock amounts from the other previous js tests are considered too (1000 + 500 + 2000)
    ];
    const parts_unlock_four_months = [
      { t: "name", v: "FragUnlock" },
      { t: "sender", v: account },
      { t: "amount", v: 600 }, // aggregated lock amounts from the other previous js tests are considered too (1000 + 500 + 2000)
    ];

    // execute first lock
    const typedData_two_weeks = eip712_message(chainId, parts_two_weeks, contract.address);
    const private_key = new Buffer.from("4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d", 'hex');
    const signature_two_weeks = ethSignUtil.signTypedData({privateKey: private_key, data: typedData_two_weeks, version: ethSignUtil.SignTypedDataVersion.V4});
    const result_two_weeks = await contract.lock(signature_two_weeks, parts_two_weeks[2].v, parts_two_weeks[3].v, { from: account });
    truffleAssert.eventEmitted(result_two_weeks, 'Lock');

    // execute second lock
    const typedData_three_months = eip712_message(chainId, parts_three_months, contract.address);
    const signature_three_months = ethSignUtil.signTypedData({privateKey: private_key, data: typedData_three_months, version: ethSignUtil.SignTypedDataVersion.V4});
    const result_three_months = await contract.lock(signature_three_months, parts_three_months[2].v, parts_three_months[3].v, { from: account });
    truffleAssert.eventEmitted(result_three_months, 'Lock');

    // execute third lock
    const typedData_one_year = eip712_message(chainId, parts_one_year, contract.address);
    const signature_one_year = ethSignUtil.signTypedData({privateKey: private_key, data: typedData_one_year, version: ethSignUtil.SignTypedDataVersion.V4});
    const result_one_year = await contract.lock(signature_one_year, parts_one_year[2].v, parts_one_year[3].v, { from: account });
    truffleAssert.eventEmitted(result_one_year, 'Lock');

    // execute unlock after one month
    const duration = time.duration.weeks(4);
    await time.increase(duration);

    const typedDataUnlock = eip712_message_unlock(chainId, parts_unlock, contract.address);
    const signature_unlock = ethSignUtil.signTypedData({privateKey: private_key, data: typedDataUnlock, version: ethSignUtil.SignTypedDataVersion.V4});
    const result_unlock = await contract.unlock(signature_unlock, { from: account });
    truffleAssert.eventEmitted(result_unlock, 'Unlock');

    // execute unlock after four months
    const duration_four_months = time.duration.weeks(20);
    await time.increase(duration_four_months);

    const typedDataUnlock_four_months = eip712_message_unlock(chainId, parts_unlock_four_months, contract.address);
    const signature_unlock_four_months = ethSignUtil.signTypedData({privateKey: private_key, data: typedDataUnlock_four_months, version: ethSignUtil.SignTypedDataVersion.V4});
    await contract.unlock(signature_unlock_four_months, { from: account });
    truffleAssert.eventEmitted(result_unlock, 'Unlock');

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
