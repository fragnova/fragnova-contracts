pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract HastenDAOToken is ERC20 {
    uint256 constant INITIAL_SUPPLY = 1048576 * (10 ** 18);

    constructor() ERC20("Hasten DAO Token", "CODE") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
