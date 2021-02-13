var daoToken = artifacts.require("HastenDAOToken");
var nft = artifacts.require("HastenScript");

module.exports = function(deployer) {
  deployer.deploy(daoToken);
  deployer.deploy(nft);
};