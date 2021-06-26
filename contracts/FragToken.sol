pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract FragmentDAOToken is ERC20 {
    uint256 constant INITIAL_SUPPLY = 100000000 * (10 ** 18);

    constructor() ERC20("Frag Utility Token", "FRAG") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
