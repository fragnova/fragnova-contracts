import {HardhatUserConfig} from "hardhat/config";
import '@primitivefi/hardhat-dodoc';
//import 'solidity-docgen'; // hardhat-dodoc is currently better than solidity-docgen (according to me) so we are using that

const config: HardhatUserConfig = {
    solidity: "0.8.9",
}


export default config;
