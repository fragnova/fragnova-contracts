/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "openzeppelin-solidity/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract FRAGToken is ERC20, ERC20Permit, ERC20Votes, Ownable {
    uint8 constant DECIMALS = 12; // Preferred for Fragnova (Substrate)
    uint256 constant INITIAL_SUPPLY = 1000000000 * (10**DECIMALS);
    uint256 constant LOCK_DURATION = 45500; // Roughly 1 week

    mapping(address => uint256) private _locksAmount;
    mapping(address => uint256) private _locksBlock;

    // Fragnova chain will listen to those events
    event Lock(address indexed sender, bytes signature, uint256 amount);
    event Unlock(address indexed sender, bytes signature, uint256 amount);

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

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
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
            keccak256(
                abi.encodePacked(
                    "FragLock",
                    msg.sender,
                    uint64(block.chainid),
                    amount
                )
            )
        );
        require(
            msg.sender == ECDSA.recover(hash, signature),
            "Invalid signature"
        );

        _locksAmount[msg.sender] = amount;
        _locksBlock[msg.sender] = block.number;

        transfer(address(this), amount);

        // We need to propagate the signature because it's the only reliable way to fetch the public key
        // of the sender from other chains.
        emit Lock(msg.sender, signature, amount);
    }

    function unlock(bytes calldata signature) external {
        require(
            block.number > _locksBlock[msg.sender] + LOCK_DURATION,
            "Lock didn't expire"
        );

        uint256 amount = _locksAmount[msg.sender];
        require(amount > 0, "Amount must be greater than 0");

        // make sure the signature is valid
        bytes32 hash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    "FragUnlock",
                    msg.sender,
                    uint64(block.chainid),
                    amount
                )
            )
        );
        require(
            msg.sender == ECDSA.recover(hash, signature),
            "Invalid signature"
        );

        // reset the stake
        _locksAmount[msg.sender] = 0;
        _locksBlock[msg.sender] = 0;

        // return the stake
        transfer(msg.sender, amount);

        // send events
        // this will be used by the Fragnova chain to unlock the stake
        // and potentially remove the stake from many protos automatically
        emit Unlock(msg.sender, signature, amount);
    }
}
