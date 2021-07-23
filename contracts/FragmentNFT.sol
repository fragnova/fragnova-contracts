pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Ownable.sol";

abstract contract FragmentNFT is ERC721Enumerable, Ownable {
    using SafeERC20 for IERC20;

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
