/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract FRAGToken is ERC20, ERC20Permit, Ownable {
    uint8 constant DECIMALS = 12; // Preferred for Fragnova (Substrate)
    uint256 constant INITIAL_SUPPLY = 10_000_000_000 * (10**DECIMALS); 
    uint256 private constant _TIMELOCK = 1 weeks;

    mapping(address => uint256) private _locksAmount;
    mapping(address => uint256) private _locksBlock;
    mapping(address => uint256) private _locktime;

    enum Period {
        TwoWeeks,
        OneMonth,
        ThreeMonths,
        SixMonths,
        OneYear
    }

    uint256 private _lockCooldown = 45500; // Roughly 1 week

    // Fragnova chain will listen to those events
    event Lock(address indexed sender, bytes signature, uint256 amount, uint8 lock_period);
    event Unlock(address indexed sender, bytes signature, uint256 amount);

    constructor()
        ERC20("Fragnova Network Token", "FRAG")
        ERC20Permit("Fragnova Network Token")
    {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    function inflate(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function deflate(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }

    function lock(uint256 amount, bytes calldata signature, uint8 lock_period) external {
        require(amount > 0, "Amount must be greater than 0");
        require(lock_period >= 0 && lock_period <= 4, "Time lock period not allowed");

        // make sure the signature is valid
        bytes32 hash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    "FragLock",
                    msg.sender,
                    uint64(block.chainid),
                    amount,
                    lock_period
                )
            )
        );
        require(
            msg.sender == ECDSA.recover(hash, signature),
            "Invalid signature"
        );

        // add to current locked amount
        _locksAmount[msg.sender] = _locksAmount[msg.sender] + amount;

        if(lock_period == uint256(Period.TwoWeeks))
            _locktime[msg.sender] = block.timestamp + (2 * _TIMELOCK);
        
        else if(lock_period == uint256(Period.OneMonth))
            _locktime[msg.sender] = block.timestamp + (4 * _TIMELOCK);

        else if(lock_period == uint256(Period.ThreeMonths))
            _locktime[msg.sender] = block.timestamp + (13 * _TIMELOCK);

        else if(lock_period == uint256(Period.SixMonths))
            _locktime[msg.sender] = block.timestamp + (26 * _TIMELOCK);

        else if(lock_period == uint256(Period.OneYear))
            _locktime[msg.sender] = block.timestamp + (52 * _TIMELOCK);

        transfer(address(this), amount);

        // We need to propagate the signature because it's the only reliable way to fetch the public key
        // of the sender from other chains.
        // emit total amount of locked tokens
        emit Lock(msg.sender, signature, _locksAmount[msg.sender], lock_period);
    }

    function unlock(bytes calldata signature) external {
        require(
            _locktime[msg.sender] != 0 && block.timestamp > _locktime[msg.sender],
            "Timelock didn't expire"
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
        _locktime[msg.sender] = 0;

        // return the stake
        transfer(msg.sender, amount);

        // send events
        // this will be used by the Fragnova chain to unlock the stake
        // and potentially remove the stake from many protos automatically
        emit Unlock(msg.sender, signature, amount);
    }

    function getTimeLock() external view returns(uint256) {
        return _locktime[msg.sender];
    }
}
