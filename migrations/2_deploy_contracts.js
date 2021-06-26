const fs = require('fs');

var daoToken = artifacts.require("FragmentDAOToken");
var nft = artifacts.require("FragmentTemplate");
var nftProxy = artifacts.require("FragmentTemplateProxy");
var nftEntity = artifacts.require("FragmentEntity");
var nftEntityProxy = artifacts.require("FragmentEntityProxy");
var admin = artifacts.require("FragmentProxyAdmin");

module.exports = async function (deployer, network) {
  console.log("Network: " + network);

  await deployer.deploy(nft);
  await deployer.deploy(nftEntity);
  await deployer.deploy(daoToken);

  fs.writeFile("deployer-utils/nft-bytecode.txt", nft.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/nftProxy-bytecode.txt", nftProxy.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/entity-bytecode.txt", nftEntity.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/entityProxy-bytecode.txt", nftEntityProxy.bytecode, (_r, _e) => { });
  fs.writeFile("deployer-utils/admin-bytecode.txt", admin.bytecode, (_r, _e) => { });
};