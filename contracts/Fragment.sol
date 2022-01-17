/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";
import "openzeppelin-solidity/contracts/utils/Create2.sol";
import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";
import "./Ownable.sol";
import "./IEntity.sol";
import "./IVault.sol";
import "./IUtility.sol";
import "./RoyaltiesReceiver.sol";
import "./ClonesWithCallData.sol";

struct StakeData {
    // Pack to 32 bytes
    // ALWAYS ADD TO THE END
    uint256 amount;
    uint256 blockStart;
    uint256 blockUnlock;
}

// this contract uses proxy
contract Fragment is
    ERC721Enumerable,
    Ownable,
    Initializable,
    RoyaltiesReceiver
{
    function name() public view virtual override returns (string memory) {
        return "Asset Store";
    }

    function symbol() public view virtual override returns (string memory) {
        return "AS";
    }

    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;

    // sidechain will listen to those, side chain deals with rewards allocations etc
    event Stake(
        bytes32 indexed fragmentHash,
        address indexed owner,
        uint256 amount
    );

    // a new wild entity appeared on the grid
    // this is necessary to make the link with the sidechain
    event Spawn(
        bytes32 indexed fragmentHash,
        address entityContract,
        address vaultContract
    );

    // Unstructured storage slots
    bytes32 private constant SLOT_stakeLock =
        keccak256("fragcolor.fragment.stakeLock");
    bytes32 private constant SLOT_entityLogic =
        keccak256("fragcolor.fragment.entityLogic");
    bytes32 private constant SLOT_vaultLogic =
        keccak256("fragcolor.fragment.vaultLogic");
    bytes32 private constant SLOT_utilityToken =
        keccak256("fragcolor.fragment.utilityToken");
    bytes32 private constant SLOT_utilityLibrary =
        keccak256("fragcolor.fragment.utilityLibrary");
    bytes32 private constant SLOT_controller =
        keccak256("fragcolor.fragment.controller");

    // list of referencing fragments to resolve dependency trees
    bytes32 private constant FRAGMENT_ATTACH_NONCE =
        keccak256("fragcolor.fragment.attach.nonce");
    bytes32 private constant FRAGMENT_ATTACH_AUTHS =
        keccak256("fragcolor.fragment.attach.nonce");
    // Use a human readable counter for IDs
    bytes32 private constant FRAGMENT_COUNTER =
        keccak256("fragcolor.fragment.counter");
    // ID -> Fragment Hash
    bytes32 private constant FRAGMENT_FRAGMENTS_ID2HASH =
        keccak256("fragcolor.fragment.fragments");
    // ID -> Fragment Hash
    bytes32 private constant FRAGMENT_FRAGMENTS_HASH2ID =
        keccak256("fragcolor.fragment.fragments");
    // keep track of rezzed entitites
    bytes32 private constant FRAGMENT_ENTITIES =
        keccak256("fragcolor.fragment.entities");
    // address to token to data map(map)
    bytes32 private constant FRAGMENT_STAKE_A2T2D =
        keccak256("fragcolor.fragment.a2t2d.v0");
    // map token -> stakers set
    bytes32 private constant FRAGMENT_STAKE_T2A =
        keccak256("fragcolor.fragment.t2a.v0");

    constructor() ERC721("", "") Ownable() {
        // NOT INVOKED IF PROXIED
        _setUint(SLOT_stakeLock, 23500);
        setupRoyalties(payable(0), FRAGMENT_ROYALTIES_BPS);
    }

    modifier fragmentOwnerOnly(uint256 fragmentId) {
        require(
            _exists(fragmentId) && (msg.sender == ownerOf(fragmentId)),
            "Fragment: only the owner of the fragment can execute this operation"
        );
        _;
    }

    function bootstrap() public payable initializer {
        // Ownable
        Ownable._bootstrap();
        // Others
        _setUint(SLOT_stakeLock, 23500);
        _setAddress(SLOT_controller, owner());
        _setAddress(
            SLOT_utilityLibrary,
            address(0x87A26d575DA6d8e2993EAD77f8f6CD12CAd361bC)
        );
        _setAddress(
            SLOT_entityLogic,
            address(0x5d90907E6081F0b1F20d49F1dE7C7066Ea044769)
        );
        _setAddress(
            SLOT_vaultLogic,
            address(0xA439872b04aD580d9D573E41fD28a693B4B97515)
        );
        setupRoyalties(payable(owner()), FRAGMENT_ROYALTIES_BPS);
    }

    function getUint(bytes32 slot) public view returns (uint256 value) {
        assembly {
            value := sload(slot)
        }
    }

    function _setUint(bytes32 slot, uint256 value) private {
        assembly {
            sstore(slot, value)
        }
    }

    function setUint(bytes32 slot, uint256 value) external onlyOwner {
        _setUint(slot, value);
    }

    function getAddress(bytes32 slot) public view returns (address value) {
        assembly {
            value := sload(slot)
        }
    }

    function _setAddress(bytes32 slot, address value) private {
        assembly {
            sstore(slot, value)
        }
    }

    function setAddress(bytes32 slot, address value) external onlyOwner {
        _setAddress(slot, value);
    }

    function getUtilityLibrary() public view returns (address addr) {
        bytes32 slot = SLOT_utilityLibrary;
        assembly {
            addr := sload(slot)
        }
    }

    function getController() public view returns (address addr) {
        bytes32 slot = SLOT_controller;
        assembly {
            addr := sload(slot)
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "Fragment: URI query for nonexistent token");

        return "";
    }

    function contractURI() public view returns (string memory) {
        IUtility ut = IUtility(getUtilityLibrary());
        return ut.buildFragmentRootMetadata(owner(), FRAGMENT_ROYALTIES_BPS);
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

    function idOf(bytes32 fragmentHash) external view returns (uint256) {
        uint256[1] storage s;
        bytes32 sslot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(FRAGMENT_FRAGMENTS_HASH2ID, fragmentHash)
                )
            )
        );
        assembly {
            s.slot := sslot
        }

        return s[0];
    }

    function hashOf(uint256 fragmentId) public view returns (bytes32) {
        bytes32[1] storage s;
        bytes32 sslot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(FRAGMENT_FRAGMENTS_ID2HASH, fragmentId)
                )
            )
        );
        assembly {
            s.slot := sslot
        }

        return s[0];
    }

    function getEntities(uint256 fragmentId)
        external
        view
        returns (address[] memory entities)
    {
        EnumerableSet.AddressSet[1] storage s;
        bytes32 slot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_ENTITIES, fragmentId)))
        );
        assembly {
            s.slot := slot
        }

        uint256 len = s[0].length();
        entities = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            entities[i] = s[0].at(i);
        }
    }

    function isEntityOf(address addr, uint256 fragmentId)
        external
        view
        returns (bool)
    {
        EnumerableSet.AddressSet[1] storage s;
        bytes32 slot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_ENTITIES, fragmentId)))
        );
        assembly {
            s.slot := slot
        }

        return s[0].contains(addr);
    }

    function _getChainId() private view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    function addAuth(address addr) external onlyOwner {
        EnumerableSet.AddressSet[1] storage auths;
        bytes32 slot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_ATTACH_AUTHS)))
        );
        assembly {
            auths.slot := slot
        }
        auths[0].add(addr);
    }

    function delAuth(address addr) external onlyOwner {
        EnumerableSet.AddressSet[1] storage auths;
        bytes32 slot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_ATTACH_AUTHS)))
        );
        assembly {
            auths.slot := slot
        }
        auths[0].remove(addr);
    }

    function attach(bytes32 fragmentHash, bytes calldata signature) external {
        require(!_exists(uint256(fragmentHash)), "Fragment already attached");

        uint64[1] storage nonce;
        EnumerableSet.AddressSet[1] storage auths;
        Counters.Counter[1] storage tokenIds;
        // read from unstructured storage
        {
            bytes32 slot = bytes32(
                uint256(
                    keccak256(
                        abi.encodePacked(FRAGMENT_ATTACH_NONCE, msg.sender)
                    )
                )
            );
            assembly {
                nonce.slot := slot
            }
        }
        {
            bytes32 slot = bytes32(
                uint256(keccak256(abi.encodePacked(FRAGMENT_ATTACH_AUTHS)))
            );
            assembly {
                auths.slot := slot
            }
        }
        {
            bytes32 slot = bytes32(
                uint256(keccak256(abi.encodePacked(FRAGMENT_COUNTER)))
            );
            assembly {
                tokenIds.slot := slot
            }
        }

        // increment nonce
        nonce[0]++;

        // Authenticate this operation
        {
            bytes32 hash = ECDSA.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        fragmentHash,
                        _getChainId(),
                        msg.sender,
                        nonce[0]
                    )
                )
            );

            address auth = ECDSA.recover(hash, signature);

            require(auths[0].contains(auth), "Invalid signature");
        }

        tokenIds[0].increment();
        uint256 tokenId = tokenIds[0].current();

        // Store to ID 2 Hash table
        {
            bytes32[1] storage fragmentHashStorage;
            bytes32 slot = bytes32(
                uint256(
                    keccak256(
                        abi.encodePacked(FRAGMENT_FRAGMENTS_ID2HASH, tokenId)
                    )
                )
            );
            assembly {
                fragmentHashStorage.slot := slot
            }
            fragmentHashStorage[0] = fragmentHash;
        }

        // Store to Hash 2 ID table
        {
            uint256[1] storage fragmentIDStorage;
            bytes32 slot = bytes32(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            FRAGMENT_FRAGMENTS_HASH2ID,
                            fragmentHash
                        )
                    )
                )
            );
            assembly {
                fragmentIDStorage.slot := slot
            }
            require(fragmentIDStorage[0] == 0, "Fragment already attached");
            fragmentIDStorage[0] = tokenId;
        }

        _mint(msg.sender, tokenId);
    }

    function spawn(
        uint256 fragmentId,
        string memory tokenName,
        string memory tokenSymbol,
        bool unique,
        bool updateable,
        uint256 maxSupply
    )
        external
        fragmentOwnerOnly(fragmentId)
        returns (address entity, address vault)
    {
        bytes32 fragmentHash = hashOf(fragmentId);
        {
            bytes memory ptr = new bytes(32);
            assembly {
                mstore(add(ptr, 0x20), fragmentHash)
            }
            entity = ClonesWithCallData.cloneWithCallDataProvision(
                getAddress(SLOT_entityLogic),
                ptr
            );
            vault = ClonesWithCallData.cloneWithCallDataProvision(
                getAddress(SLOT_vaultLogic),
                ptr
            );
        }

        // entity
        {
            FragmentInitData memory params = FragmentInitData(
                fragmentId,
                maxSupply,
                address(this),
                payable(vault),
                unique,
                updateable
            );

            IEntity(entity).bootstrap(tokenName, tokenSymbol, params);

            // keep track of this new contract
            EnumerableSet.AddressSet[1] storage s;
            bytes32 slot = bytes32(
                uint256(
                    keccak256(abi.encodePacked(FRAGMENT_ENTITIES, fragmentId))
                )
            );
            assembly {
                s.slot := slot
            }
            s[0].add(entity);
        }

        // vault
        {
            IVault(payable(vault)).bootstrap(entity, address(this));
        }

        // emit events
        emit Spawn(fragmentHash, entity, vault);
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        setupRoyalties(payable(newOwner), FRAGMENT_ROYALTIES_BPS);
        super.transferOwnership(newOwner);
    }

    /*
        TODO Decentralization.
        For now we keep control of this but in the future we want to have it controlled by decentralized votes
        Useful to remove spam and abuse of the system.
        Notice that referencing works will still work! We on purpose don't clean up data for now.
        Even staking and all still works.
        This literally just removes the ability to trade it and removes it from showing on portals like OpenSea.
    */
    function banish(uint256[] memory fragmentIds) external onlyOwner {
        for (uint256 i = 0; i < fragmentIds.length; i++) {
            _burn(fragmentIds[i]);
        }
    }

    /*
        Useful to remove spam and abuse of the system.
        Notice that referencing works will still work! We on purpose don't clean up data for now.
        Even staking and all still works.
        This literally just removes the ability to trade it and removes it from showing on portals like OpenSea.
    */
    function burn(uint256 fragmentId) external fragmentOwnerOnly(fragmentId) {
        _burn(fragmentId);
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
