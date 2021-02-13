var daoToken = artifacts.require("HastenDAOToken");
var nft = artifacts.require("HastenProgram");

module.exports = function(deployer) {
  deployer.deploy(daoToken);
  deployer.deploy(nft);
};