const fs = require('fs');

var daoToken = artifacts.require("FragmentDAOToken");
var nft = artifacts.require("Fragment");
var nftProxy = artifacts.require("FragmentProxy");
var nftEntity = artifacts.require("Entity");
var nftEntityProxy = artifacts.require("RezProxy");
var admin = artifacts.require("FragmentProxyAdmin");
var vault = artifacts.require("Vault");
var utility = artifacts.require("Utility");

module.exports = async function (deployer, network) {
  console.log("Network: " + network);

  await deployer.deploy(nft);
  await deployer.deploy(nftEntity);
  await deployer.deploy(daoToken);
  await deployer.deploy(vault);
  await deployer.deploy(utility);

  fs.writeFile("deployer-utils/utility-bytecode.txt", utility.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/nft-bytecode.txt", nft.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/nftProxy-bytecode.txt", nftProxy.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/entity-bytecode.txt", nftEntity.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/admin-bytecode.txt", admin.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/vault-bytecode.txt", vault.bytecode, (_r, _e) => { });
};