/// SPDX-License-Identifier: BUSL-1.1
/// Copyright © 2021 Fragcolor Pte. Ltd.

pragma solidity >=0.8.0 <0.9.0;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/// @title FRAG Token Smart Contract
/// @dev Extends ERC721 Non-Fungible Token Standard basic implementation.
contract FRAGToken is ERC20, ERC20Permit, Ownable {
    uint8 constant DECIMALS = 12; // Preferred for Fragnova (Substrate)
    uint256 constant INITIAL_SUPPLY = 10_000_000_000 * (10**DECIMALS); 
    uint256 private constant _TIMELOCK = 1 weeks;

    /// @notice **Mapping** that maps a **Public Account Address** to the **amount of FRAG Token is currently locked by the Public Account Address**
    mapping(address => uint256) private _locksAmount;
    /// @notice ???
    mapping(address => uint256) private _locksBlock;
    /// @notice **Mapping** that maps a **Public Account Address** to the
    /// **block-timestamp after which the Public Account Address can unlock the FRAG Token that is currently locked by it**
    mapping(address => uint256) private _locktime;

    /// @notice **Enum** represents the **different time periods** in which **some FRAG Token can be locked**
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

    /// @notice Get the **maximum number of decimal places** of the FRAG Token
    /// @return Maximum number of decimal places of the FRAG Token
    function decimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    /// @notice Increase the Token Supply of the FRAG Token
    /// @param to Public Account Address to transfer the newly-mined FRAG Token to
    /// @param amount Amount of FRAG Token to mint
    function inflate(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Decrease the Token Supply of the FRAG Token
    /// @param account Public Account Address to transfer the newly-mined FRAG Token to
    /// @param amount Amount of FRAG Token to burn
    function deflate(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }

    /// @notice Lock some FRAG Token
    /// @param signature Signature signed by the caller of this function indicating the amount of FRAG token (param `amount`) that the caller wants to lock
    /// and the time period (param `time_period`) he wants to lock it for
    /// @param amount Amount of FRAG Token to lock
    /// @param lock_period **Index** of the **`Period` enum variant** that **you want to use**.
    function lock(bytes calldata signature, uint256 amount, uint8 lock_period) external {
        require(amount > 0, "Amount must be greater than 0");
        require(lock_period >= 0 && lock_period <= 4, "Time lock period not allowed");

        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(abi.encodePacked("Msg(string name,address sender,uint256 amount,uint8 lock_period)")),
                    keccak256(abi.encodePacked("FragLock")),
                    msg.sender,
                    amount,
                    lock_period
                )
            )
        );
        
        require(
            msg.sender == ECDSA.recover(digest, signature),
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

    /// @notice Unlock the FRAG Token that is currently locked under your name
    /// @param signature Signature signed by the caller of this function indicating the amount of FRAG Token that the caller wants to unlock
    function unlock(bytes calldata signature) external {
        require(
            _locktime[msg.sender] != 0 && block.timestamp > _locktime[msg.sender],
            "Timelock didn't expire"
        );

        uint256 amount = _locksAmount[msg.sender];
        require(amount > 0, "Amount must be greater than 0");

        // make sure the signature is valid
         bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256(abi.encodePacked("Msg(string name,address sender,uint256 amount)")),
                    keccak256(abi.encodePacked("FragUnlock")),
                    msg.sender,
                    amount
                )
            )
        );
        
        require(
            msg.sender == ECDSA.recover(digest, signature),
            "Invalid signature"
        );

        // reset the stake
        delete _locksAmount[msg.sender];
        delete _locksBlock[msg.sender];
        delete _locktime[msg.sender];

        // return the stake
        transfer(msg.sender, amount);

        // send events
        // this will be used by the Fragnova chain to unlock the stake
        // and potentially remove the stake from many protos automatically
        emit Unlock(msg.sender, signature, amount);
    }

    /// @notice Get the amount of FRAG Token that is currently locked under your name
    /// @return Amount of FRAG Token that is currently locked under your name
    function getTimeLock() external view returns(uint256) {
        return _locktime[msg.sender];
    }
}
