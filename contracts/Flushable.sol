pragma solidity ^0.8.0;

import "./Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract Flushable is Ownable {
    using SafeERC20 for IERC20;

    function flush(address[] memory tokens) public onlyOwner {
        address payable to = payable(owner());
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == address(0)) {
                // assume eth
                to.transfer(address(this).balance);
            } else {
                IERC20 token = IERC20(tokens[i]);
                token.safeTransferFrom(
                    address(this),
                    to,
                    token.balanceOf(address(this))
                );
            }
        }
    }
}
