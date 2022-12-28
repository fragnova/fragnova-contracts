/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract FRAGToken is ERC20, ERC20Permit, Ownable{
    uint8 constant DECIMALS = 12; // Preferred for Fragnova (Substrate)
    uint256 constant INITIAL_SUPPLY = 10_000_000_000 * (10**DECIMALS); 
    uint256 private constant _TIMELOCK = 1 weeks;

    struct LockInfo {
        uint256 locktime;
        uint256 amount;
    }

    mapping(address => LockInfo[]) private _lockInfos;

    enum Period {
        TwoWeeks,
        OneMonth,
        ThreeMonths,
        SixMonths,
        OneYear
    }

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

        LockInfo memory lockInfo;
        lockInfo.amount = amount;

        if(lock_period == uint256(Period.TwoWeeks)) 
            lockInfo.locktime = block.timestamp + (2 * _TIMELOCK);
        
        
        else if(lock_period == uint256(Period.OneMonth))
            lockInfo.locktime = block.timestamp + (4 * _TIMELOCK);
        

        else if(lock_period == uint256(Period.ThreeMonths))
            lockInfo.locktime = block.timestamp + (13 * _TIMELOCK);
        

        else if(lock_period == uint256(Period.SixMonths))
            lockInfo.locktime = block.timestamp + (26 * _TIMELOCK);
        

        else if(lock_period == uint256(Period.OneYear))
            lockInfo.locktime = block.timestamp + (52 * _TIMELOCK);
        
        else revert("This revert should not happen.");
        
        _lockInfos[msg.sender].push(lockInfo);

        transfer(address(this), amount);

        // We need to propagate the signature because it's the only reliable way to fetch the public key
        // of the sender from other chains.
        // emit total amount of locked tokens
        emit Lock(msg.sender, signature, lockInfo.amount, lock_period);
    }

    function unlock(bytes calldata signature) external {

        uint256 amount = 0;
        // loop over all the locks performed by the sender and calculate the aggregate unlockable
        for (uint i = _lockInfos[msg.sender].length - 1; i >= 0 ; i--) {
            if(_lockInfos[msg.sender][i].locktime < block.timestamp) {
                amount += _lockInfos[msg.sender][i].amount;
                _lockInfos[msg.sender].pop();
            }
            if(i == 0) { // This to avoid Arithmetic overflow when i == 0.
                break;
            }
        }

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

        require(amount > 0, "Nothing available to unlock.");

        // return the stake
        transfer(msg.sender, amount);

        // send events
        // this will be used by the Fragnova chain to unlock the stake
        // and potentially remove the stake from many protos automatically
        emit Unlock(msg.sender, signature, amount);
    }
}
