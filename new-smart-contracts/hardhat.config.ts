import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import '@openzeppelin/hardhat-upgrades'; // Karan Da Kiya Hua

const PRIVATE_KEY = process.env.PRIVATE_KEY;

const config: HardhatUserConfig = {
  solidity: "0.8.17",
  networks: {
    // Note: "hardhat" is the default network
    hardhat: {
      chainId: 1, // EthereumMainnet
    },
    localhost: {
      url: "http://127.0.0.1:8545/",
      chainId: 31337,
      // accounts: [PRIVATE_KEY]
    }
  }
};

export default config;
