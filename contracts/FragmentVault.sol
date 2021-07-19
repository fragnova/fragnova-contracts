pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "./FragmentTemplate.sol";
import "./Ownable.sol";

contract FragmentVault is Initializable {
    using SafeERC20 for IERC20;

    bytes32 private constant SLOT_templatesLibrary =
        bytes32(uint256(keccak256("fragcolor.vault.templatesLibrary")) - 1);
    bytes32 private constant SLOT_entityContract =
        bytes32(uint256(keccak256("fragcolor.vault.entityContract")) - 1);

    function owner() public view virtual returns (address) {
        address templatesLibrary;
        bytes32 slot = SLOT_templatesLibrary;
        assembly {
            templatesLibrary := sload(slot)
        }
        FragmentTemplate t = FragmentTemplate(templatesLibrary);
        return t.owner();
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Caller is not the owner");
        _;
    }

    constructor() {}

    receive() external payable {}

    function bootstrap(address entityContract, address templatesLibrary)
        public
        initializer
    {
        bytes32 slot = SLOT_entityContract;
        assembly {
            sstore(slot, entityContract)
        }

        slot = SLOT_templatesLibrary;
        assembly {
            sstore(slot, templatesLibrary)
        }
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        public
        onlyOwner
    {
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    }

    function recoverETH(uint256 amount) public onlyOwner {
        payable(owner()).transfer(amount);
    }
}
