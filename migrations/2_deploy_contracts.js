const fs = require('fs');

var fragToken = artifacts.require("FRAGToken");
var nftProxy = artifacts.require("FragmentProxy");
var admin = artifacts.require("FragmentProxyAdmin");
var vault = artifacts.require("Vault");
var utility = artifacts.require("Utility");

module.exports = async function (deployer, network) {
  console.log("Network: " + network);

  await deployer.deploy(fragToken);
  await deployer.deploy(vault);
  await deployer.deploy(utility);

  fs.writeFile("deployer-utils/utility-bytecode.txt", utility.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/nftProxy-bytecode.txt", nftProxy.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/admin-bytecode.txt", admin.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/vault-bytecode.txt", vault.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/fragToken-bytecode.txt", fragToken.bytecode, (_r, _e) => { });
};