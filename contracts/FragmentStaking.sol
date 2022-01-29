/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import "./Ownable.sol";
import "./UnstructuredStorage.sol";
import "./ClonesWithCalldata.sol";

struct StakeData {
    // Pack to 32 bytes
    // ALWAYS ADD TO THE END
    uint256 amount;
    uint256 blockStart;
    uint256 blockUnlock;
}

// this contract uses proxy
contract FragmentStaking is Ownable, Initializable, UnstructuredStorage {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    // sidechain will listen to those, side chain deals with rewards allocations etc
    event Stake(
        bytes32 indexed fragmentHash,
        address indexed owner,
        uint256 amount
    );

    // Unstructured storage slots
    bytes32 private constant SLOT_stakeLock =
        keccak256("fragcolor.fragment.stakeLock");
    bytes32 private constant SLOT_utilityToken =
        keccak256("fragcolor.fragment.utilityToken");

    // address to token to data map(map)
    bytes32 private constant FRAGMENT_STAKE_A2T2D =
        keccak256("fragcolor.fragment.a2t2d.v0");
    // map token -> stakers set
    bytes32 private constant FRAGMENT_STAKE_T2A =
        keccak256("fragcolor.fragment.t2a.v0");

    constructor() Ownable() {
        // NOT INVOKED IF PROXIED
        _setUint(SLOT_stakeLock, 23500);
    }

    function bootstrap() public payable initializer {
        // Ownable
        Ownable._bootstrap();
        // Others
        _setUint(SLOT_stakeLock, 23500);
    }

    function stakeOf(bytes32 fragmentHash, address staker)
        external
        view
        returns (uint256 amount, uint256 blockStart)
    {
        StakeData[1] storage data;
        bytes32 slot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(FRAGMENT_STAKE_A2T2D, staker, fragmentHash)
                )
            )
        );
        assembly {
            data.slot := slot
        }

        return (data[0].amount, data[0].blockStart);
    }

    function getStakeAt(bytes32 fragmentHash, uint256 index)
        external
        view
        returns (address staker, uint256 amount)
    {
        EnumerableSet.AddressSet[1] storage s;
        bytes32 sslot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_STAKE_T2A, fragmentHash))
            )
        );
        assembly {
            s.slot := sslot
        }

        staker = s[0].at(index);
        StakeData[1] storage data;
        bytes32 slot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(FRAGMENT_STAKE_A2T2D, staker, fragmentHash)
                )
            )
        );
        assembly {
            data.slot := slot
        }
        amount = data[0].amount;
    }

    function getStakeCount(bytes32 fragmentHash)
        external
        view
        returns (uint256)
    {
        EnumerableSet.AddressSet[1] storage s;
        bytes32 sslot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_STAKE_T2A, fragmentHash))
            )
        );
        assembly {
            s.slot := sslot
        }

        return s[0].length();
    }

    function stake(bytes32 fragmentHash, uint256 amount) external {
        IERC20 ut = IERC20(getAddress(SLOT_utilityToken));
        assert(address(ut) != address(0));

        uint256 balance = ut.balanceOf(msg.sender);
        require(balance >= amount, "Fragment: not enough tokens to stake");

        StakeData[1] storage data;
        bytes32 slot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(
                        FRAGMENT_STAKE_A2T2D,
                        msg.sender,
                        fragmentHash
                    )
                )
            )
        );
        assembly {
            data.slot := slot
        }

        // sum it as users might add more tokens to the stake
        data[0].amount += amount;
        data[0].blockStart = block.number;
        data[0].blockUnlock = block.number + getUint(SLOT_stakeLock);

        EnumerableSet.AddressSet[1] storage adata;
        bytes32 aslot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_STAKE_T2A, fragmentHash))
            )
        );
        assembly {
            adata.slot := aslot
        }

        adata[0].add(msg.sender);

        emit Stake(fragmentHash, msg.sender, data[0].amount);

        ut.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(bytes32 fragmentHash) external {
        IERC20 ut = IERC20(getAddress(SLOT_utilityToken));
        assert(address(ut) != address(0));

        StakeData[1] storage data;
        bytes32 slot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(
                        FRAGMENT_STAKE_A2T2D,
                        msg.sender,
                        fragmentHash
                    )
                )
            )
        );
        assembly {
            data.slot := slot
        }

        // find amount
        uint256 amount = data[0].amount;
        assert(amount > 0);
        // require lock time
        require(
            block.number >= data[0].blockUnlock,
            "Fragment: cannot unstake yet"
        );
        // reset data
        data[0].amount = 0;
        data[0].blockStart = 0;
        data[0].blockUnlock = 0;

        EnumerableSet.AddressSet[1] storage adata;
        bytes32 aslot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_STAKE_T2A, fragmentHash))
            )
        );
        assembly {
            adata.slot := aslot
        }

        adata[0].remove(msg.sender);

        emit Stake(fragmentHash, msg.sender, 0);

        ut.safeTransfer(msg.sender, amount);
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        onlyOwner
    {
        assert(tokenAddress != getAddress(SLOT_utilityToken)); // prevent removal of our utility token!
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    }

    function recoverETH(uint256 amount) external onlyOwner {
        payable(owner()).transfer(amount);
    }
}
