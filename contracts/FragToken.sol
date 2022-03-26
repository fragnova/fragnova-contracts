/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "openzeppelin-solidity/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract FRAGToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    uint256 constant INITIAL_SUPPLY = 1000000000 * (10**18);

    mapping(address => uint256) private _locks;
    address private _authority;

    // Fragnova chain will listen to those events
    event Lock(address indexed owner, bytes signature, uint256 amount);
    event Unlock(address indexed owner, bytes signature, uint256 amount);

    constructor()
        ERC20("Fragnova Network Token", "FRAG")
        ERC20Permit("Fragnova Network Token")
    {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    // The functions below are overrides required by Solidity.

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._mint(to, amount);
    }

    function _burn(address account, uint256 amount)
        internal
        override(ERC20, ERC20Votes)
    {
        super._burn(account, amount);
    }

    function setAuthority(address authority) public onlyOwner {
        _authority = authority;
    }

    function inflate(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    function deflate(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }

    function lock(uint256 amount, bytes calldata signature) external {
        require(amount > 0, "Amount must be greater than 0");

        // make sure the signature is valid
        bytes32 hash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(msg.sender, block.chainid, amount))
        );
        require(
            msg.sender == ECDSA.recover(hash, signature),
            "Invalid signature"
        );

        _locks[msg.sender] = amount;

        transfer(address(this), amount);

        emit Lock(msg.sender, signature, amount);
    }

    function unlock(bytes calldata signature) external {
        uint256 amount = _locks[msg.sender];

        // authenticate first
        bytes32 hash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(msg.sender, block.chainid, amount))
        );
        require(
            _authority != address(0x0) &&
                _authority == ECDSA.recover(hash, signature),
            "Invalid signature"
        );

        // reset the stake
        _locks[msg.sender] = 0;

        // return the stake
        transfer(msg.sender, amount);

        // send events
        emit Unlock(msg.sender, signature, amount);
    }
}
