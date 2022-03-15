const fs = require('fs');

var daoToken = artifacts.require("FRAGToken");
var nft = artifacts.require("Fragment");
var nftProxy = artifacts.require("FragmentProxy");
var nftEntity = artifacts.require("Entity");
var nftEntityProxy = artifacts.require("RezProxy");
var admin = artifacts.require("FragmentProxyAdmin");
var vault = artifacts.require("Vault");
var utility = artifacts.require("Utility");
var pre721 = artifacts.require("PreERC721");
var pre721Factory = artifacts.require("PreERC721Factory");
var pre721Genesis = artifacts.require("PreERC721Genesis");

module.exports = async function (deployer, network) {
  console.log("Network: " + network);

  await deployer.deploy(nft);
  await deployer.deploy(nftEntity);
  await deployer.deploy(daoToken);
  await deployer.deploy(vault);
  await deployer.deploy(utility);
  await deployer.deploy(pre721);
  await deployer.deploy(pre721Factory);
  await deployer.deploy(pre721Genesis);

  fs.writeFile("deployer-utils/utility-bytecode.txt", utility.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/nft-bytecode.txt", nft.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/nftProxy-bytecode.txt", nftProxy.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/entity-bytecode.txt", nftEntity.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/admin-bytecode.txt", admin.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/vault-bytecode.txt", vault.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/pre721-bytecode.txt", pre721.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/pre721Factory-bytecode.txt", pre721Factory.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/pre721Genesis-bytecode.txt", pre721Genesis.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/daoToken-bytecode.txt", daoToken.bytecode, (_r, _e) => { });
};