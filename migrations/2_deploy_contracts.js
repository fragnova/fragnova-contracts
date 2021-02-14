var daoToken = artifacts.require("HastenDAOToken");
var nft = artifacts.require("HastenScript");
var nftMod = artifacts.require("HastenMod");

module.exports = async function(deployer) {
  await deployer.deploy(daoToken);
  await deployer.deploy(nft);
  await deployer.deploy(nftMod, nft.address, daoToken.address);
  const dao = await daoToken.deployed();
  await dao.transfer(nftMod.address, web3.utils.toWei("1024", "ether"));
};