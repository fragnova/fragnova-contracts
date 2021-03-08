const fs = require('fs');

var daoToken = artifacts.require("HastenDAOToken");
var nft = artifacts.require("HastenScript");
var nftProxy = artifacts.require("HastenScriptProxy");
var nftMod = artifacts.require("HastenMod");
var admin = artifacts.require("HastenProxyAdmin");

module.exports = async function(deployer) {
  await deployer.deploy(daoToken);
  await deployer.deploy(nft);
  // await deployer.deploy(nftProxy);
  // await deployer.deploy(admin);
  await deployer.deploy(nftMod, nft.address, daoToken.address);
  const dao = await daoToken.deployed();
  await dao.transfer(nftMod.address, web3.utils.toWei("1024", "ether"));

  fs.writeFile("deployer-utils/nft-bytecode.txt", nft.bytecode, (_r, _e) => {});
  fs.writeFile("deployer-utils/pnft-bytecode.txt", nftProxy.bytecode, (_r, _e) => {});
  fs.writeFile("deployer-utils/dao-bytecode.txt", daoToken.bytecode, (_r, _e) => {});
  fs.writeFile("deployer-utils/admin-bytecode.txt", admin.bytecode, (_r, _e) => {});
};