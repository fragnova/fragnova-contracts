var token = artifacts.require("DAOToken");

module.exports = function(deployer) {
  deployer.deploy(token);
};