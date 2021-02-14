pragma solidity ^0.7.4;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";

contract HastenDAOToken is ERC20 {
    uint256 constant INITIAL_SUPPLY = 1048576;

    constructor() ERC20("Hasten DAO Token", "HSTN") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
