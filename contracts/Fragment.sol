/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-solidity/contracts/utils/Create2.sol";
import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./Ownable.sol";
import "./IEntity.sol";
import "./IVault.sol";
import "./IUtility.sol";
import "./IRezProxy.sol";
import "./RoyaltiesReceiver.sol";

struct StakeData {
    // Pack to 32 bytes
    // ALWAYS ADD TO THE END
    uint256 amount;
    uint256 blockStart;
    uint256 blockUnlock;
}

struct FragmentData {
    // Pack to 32 bytes
    // ALWAYS ADD TO THE END
    uint256 includeCost;
    bytes32 mutableDataHash;
    // Knowing the block we can restore the transaction even from a simple full node
    // web3.eth.getBlock(blockNumber, true) - will uncompress transactions!
    // 48 bits should be plenty for centuries...
    uint48 iDataBlockNumber; // immutable data
    uint48 mDataBlockNumber; // mutable data
    address creator;
}

// this contract uses proxy
/// @title This contract holds all the ERC-721 Fragment Tokens.
/// @dev The Royalty Payment Logic is implemented in `RoyaltiesReceiever`
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

    // mutable part updated
    event Update(uint256 indexed tokenId);

    // sidechain will listen to those, side chain deals with rewards allocations etc
    event Stake(uint256 indexed tokenId, address indexed owner, uint256 amount);

    // a new wild entity appeared on the grid
    // this is necessary to make the link with the sidechain
    event Rez(
        uint256 indexed tokenId,
        address entityContract,
        address vaultContract
    );

    // royalties related events, we use those to log them
    // this is work in progress until we define the full process
    event Reward(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 amount
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
    bytes32 private constant SLOT_runtimeCid =
        keccak256("fragcolor.fragment.runtimeCid");

    // list of referencing fragments to resolve dependency trees
    bytes32 private constant FRAGMENT_REFS =
        keccak256("fragcolor.fragment.referencing");
    // layering whitelisting
    bytes32 private constant FRAGMENT_WHITELIST =
        keccak256("fragcolor.fragment.referencing");
    // keep track of rezzed entitites
    bytes32 private constant FRAGMENT_ENTITIES =
        keccak256("fragcolor.fragment.entities");
    // fragments data storage
    bytes32 private constant FRAGMENT_DATA = keccak256("fragcolor.fragment.v0");
    // address to token to data map(map)
    bytes32 private constant FRAGMENT_STAKE_A2T2D =
        keccak256("fragcolor.fragment.a2t2d.v0");
    // map token -> stakers set
    bytes32 private constant FRAGMENT_STAKE_T2A =
        keccak256("fragcolor.fragment.t2a.v0");
    // map referenced + referencer bond
    bytes32 private constant FRAGMENT_INCLUDE_SNAPSHOT =
        keccak256("fragcolor.fragment.include-snapshot.v0");

    constructor()
        ERC721("", "")
        Ownable(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974))
    {
        // NOT INVOKED IF PROXIED
        _setUint(SLOT_stakeLock, 23500);
        setupRoyalties(payable(0), FRAGMENT_ROYALTIES_BPS);
    }

    modifier fragmentOwnerOnly(uint160 fragmentHash) {
        require(
            _exists(fragmentHash) && (msg.sender == ownerOf(fragmentHash)),
            "Fragment: only the owner of the fragment can execute this operation"
        );
        _;
    }

    function bootstrap() public payable initializer {
        // Ownable
        Ownable._bootstrap(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974));
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

    /// @dev Gets the address stored in storage slot `slot`
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

    /// @notice Loads the Address of the Utility Library from Storage
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

    /* runtime CID/Hash on chain is important to ensure it's genuine */
    function getRuntimeCid() public view returns (bytes32 cid) {
        bytes32 slot = SLOT_runtimeCid;
        assembly {
            cid := sload(slot)
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

        IUtility ut = IUtility(getUtilityLibrary());

        uint160 fragmentHash = uint160(tokenId);
        (uint64 ib, uint64 mb, bytes32 mhash) = dataOf(fragmentHash);

        return
            ut.buildFragmentMetadata(
                fragmentHash,
                mhash,
                includeCostOf(fragmentHash),
                uint256(ib),
                uint256(mb)
            );
    }

    function contractURI() public view returns (string memory) {
        IUtility ut = IUtility(getUtilityLibrary());
        return ut.buildFragmentRootMetadata(owner(), FRAGMENT_ROYALTIES_BPS);
    }

    // Get stake to include snapshot and as well as indirectly if the fragment includes the other fragment
    function getSnapshot(uint160 referenced, uint160 referencer)
        external
        view
        returns (bytes memory)
    {
        // grab the snapshot
        FragmentData[1] storage rdata;
        bytes32 slot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(
                        FRAGMENT_INCLUDE_SNAPSHOT,
                        uint160(referencer),
                        uint160(referenced)
                    )
                )
            )
        );
        assembly {
            rdata.slot := slot
        }

        return
            abi.encodePacked(
                rdata[0].includeCost,
                rdata[0].mutableDataHash,
                rdata[0].iDataBlockNumber,
                rdata[0].mDataBlockNumber
            );
    }

    function descendants(uint160 referenced)
        external
        view
        returns (uint256[] memory)
    {
        // also add this newly minted fragment to the referencing list
        EnumerableSet.UintSet[1] storage referencing;
        bytes32 slot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_REFS, referenced)))
        );
        assembly {
            referencing.slot := slot
        }

        uint256 len = referencing[0].length();
        uint256[] memory result = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = referencing[0].at(i);
        }

        return result;
    }

    // keep in mind that an empty whitelist means anyone can reference!
    // also this can effectively be used to whitelist a creator from referecing the fragment (Add)
    function whitelist(
        uint160 fragmentHash,
        address referencer,
        bool remove
    ) external fragmentOwnerOnly(fragmentHash) {
        EnumerableSet.AddressSet[1] storage referencing;
        bytes32 slot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_WHITELIST, fragmentHash))
            )
        );
        assembly {
            referencing.slot := slot
        }

        if (remove) {
            referencing[0].remove(referencer);
        } else {
            referencing[0].add(referencer);
        }
    }


    /// @notice Returns the includeCost field of the Fragment with the Token ID `fragmentHash`
    /// @param fragmentHash The Token ID of the Fragment
    function includeCostOf(uint160 fragmentHash)
        public
        view
        returns (uint256 cost)
    {
        FragmentData[1] storage data;
        bytes32 dslot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_DATA, fragmentHash)))
        );
        assembly {
            data.slot := dslot
        }

        return data[0].includeCost;
    }

    function dataOf(uint160 fragmentHash)
        public
        view
        returns (
            uint64 immutableData,
            uint64 mutableData,
            bytes32 mutableDataHash
        )
    {
        FragmentData[1] storage data;
        bytes32 dslot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_DATA, fragmentHash)))
        );
        assembly {
            data.slot := dslot
        }

        return (
            data[0].iDataBlockNumber,
            data[0].mDataBlockNumber,
            data[0].mutableDataHash
        );
    }

    function creatorOf(uint160 fragmentHash) external view returns (address) {
        FragmentData[1] storage data;
        bytes32 dslot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_DATA, fragmentHash)))
        );
        assembly {
            data.slot := dslot
        }

        return data[0].creator;
    }

    function stakeOf(uint160 fragmentHash, address staker)
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

    function getStakeAt(uint160 fragmentHash, uint256 index)
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

    function getStakeCount(uint160 fragmentHash)
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

    function stake(uint160 fragmentHash, uint256 amount) external {
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

    function unstake(uint160 fragmentHash) external {
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

    function getEntities(uint160 fragmentHash)
        external
        view
        returns (address[] memory entities)
    {
        EnumerableSet.AddressSet[1] storage s;
        bytes32 slot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_ENTITIES, fragmentHash))
            )
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

    function isEntityOf(address addr, uint160 fragmentHash)
        external
        view
        returns (bool)
    {
        EnumerableSet.AddressSet[1] storage s;
        bytes32 slot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_ENTITIES, fragmentHash))
            )
        );
        assembly {
            s.slot := slot
        }

        return s[0].contains(addr);
    }

    /// @notice Uploads a Fragment
    /// @dev The hash of the concatenation of the immutableData and the references is the ERC-721 Token ID
    /// @param immutableData The data of the Fragment.
    /// @param mutableData ¿
    /// @param references A list of references to other Proto-Fragments
    /// @param includeCost ¿
    function upload(
        bytes calldata immutableData, // immutable
        bytes calldata mutableData, // mutable
        uint160[] calldata references, // immutable The fragments that are
        uint256 includeCost // mutable
    ) external {
        // mint a new token and upload it
        // but make fragments unique by hashing them
        // THIS IS THE BIG DEAL
        // Apps just by knowing the hash can verify
        // That references are collected and were verified on upload
        // We store data in transaction inputs and so in eth blocks
        // It can be easily retreived by any full node! No need archive nodes!
        uint160 hash = uint160(
            uint256(keccak256(abi.encodePacked(immutableData, references)))
        );

        require(!_exists(hash), "Fragment: fragment already minted");

        _mint(msg.sender, hash);

        bytes32 slot = 0;

        if (references.length > 0) {
            uint256 stakeLock = getUint(SLOT_stakeLock);
            for (uint256 i = 0; i < references.length; i++) {
                uint160 referenced = references[i];

                FragmentData[1] storage fdata;
                slot = bytes32(
                    uint256(
                        keccak256(
                            abi.encodePacked(FRAGMENT_DATA, uint160(referenced))
                        )
                    )
                );
                assembly {
                    fdata.slot := slot
                }

                if (msg.sender != ownerOf(referenced)) {
                    // require stake
                    if (fdata[0].includeCost > 0) {
                        StakeData[1] storage sdata;
                        slot = bytes32(
                            uint256(
                                keccak256(
                                    abi.encodePacked(
                                        FRAGMENT_STAKE_A2T2D,
                                        msg.sender,
                                        referenced
                                    )
                                )
                            )
                        );
                        assembly {
                            sdata.slot := slot
                        }

                        require(
                            sdata[0].amount >= fdata[0].includeCost,
                            "Fragment: not enough staked amount to reference"
                        );

                        // lock the stake for a new period
                        sdata[0].blockUnlock = block.number + stakeLock;
                        includeCost = fdata[0].includeCost;
                    }

                    // check whitelist
                    {
                        EnumerableSet.AddressSet[1] storage rwhitelist;
                        slot = bytes32(
                            uint256(
                                keccak256(
                                    abi.encodePacked(
                                        FRAGMENT_WHITELIST,
                                        referenced
                                    )
                                )
                            )
                        );
                        assembly {
                            rwhitelist.slot := slot
                        }

                        require(
                            rwhitelist[0].length() == 0 ||
                                rwhitelist[0].contains(msg.sender),
                            "Fragment: creator not whitelisted"
                        );
                    }
                }

                // and snapshot the state of the referenced fragment
                // to be able to restore it later and flag this reference on as well
                FragmentData[1] storage rdata;
                slot = bytes32(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                FRAGMENT_INCLUDE_SNAPSHOT,
                                uint160(hash), // now minting fragment
                                uint160(referenced) // + referenced
                            )
                        )
                    )
                );
                assembly {
                    rdata.slot := slot
                }

                rdata[0] = fdata[0];

                // also add this newly minted fragment to the referencing list
                EnumerableSet.UintSet[1] storage referencing;
                slot = bytes32(
                    uint256(
                        keccak256(abi.encodePacked(FRAGMENT_REFS, referenced))
                    )
                );
                assembly {
                    referencing.slot := slot
                }

                referencing[0].add(hash);
            }
        }

        FragmentData[1] storage data;
        slot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_DATA, hash)))
        );
        assembly {
            data.slot := slot
        }

        data[0] = FragmentData(
            includeCost,
            keccak256(mutableData),
            uint48(block.number),
            0, // first upload, no mutation
            msg.sender
        );
    }


    /// @notice Update the Fragment with the Token Id of `fragmentId`
    /// @dev The hash of the concatenation of the immutableData and the references is the ERC-721 Token ID
    /// @param fragmentHash The Token ID (i.e the hash of the Fragment)
    /// @param mutableData The mutableData that will override the existing mutableDat
    /// @param includeCost ¿
    function update(
        uint160 fragmentHash,
        bytes calldata mutableData,
        uint256 includeCost
    ) external fragmentOwnerOnly(fragmentHash) {

        FragmentData[1] storage data;

        bytes32 dslot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_DATA, fragmentHash)))
        );

        assembly {
            // get the array of FragmentData that was stored at slot dslot (https://solidity-by-example.org/app/write-to-any-slot/)
            data.slot := dslot
        }

        data[0] = FragmentData(
            includeCost,
            keccak256(mutableData),
            data[0].iDataBlockNumber, // don't overwrite this
            uint48(block.number), // this also marks it as mutated - if not would be 0
            data[0].creator // don't overwrite this
        );

        emit Update(fragmentHash);
    }

    /// @notice Create and deploy an Entity and Vault Contract based on the Fragment with token ID `fragmenthash`. Only the owner of the Fragment with tokenID `fragmentHash` can call this function
    /// @dev Creates and Deploys 2 RezProxy Contracts. One of the 2 RezProxy Contracts delegates all its calls to the contract with address in storage slot `SLOT_entityLogic`, and the other to the contract with address in storage slot `SLOT_vaultLogic`
    /// It then adds the address of the RezProxy Contract for the Entity Implementation Contract to storage slot `keccak256(abi.encodePacked(FRAGMENT_ENTITIES, fragmentHash))`.
    /// @param fragmentHash The Token ID of the Fragment
    /// @param tokenName The name of the Entity/Vault Contract that will be created and deployed
    /// @param tokenSymbol The symbol of the Entity/Vault Contract that will be created and deployed
    /// @param unique ¿
    /// @param updateable ¿
    /// @param maxSupply ¿
    function rez(
        uint160 fragmentHash,
        string calldata tokenName,
        string calldata tokenSymbol,
        bool unique,
        bool updateable,
        uint96 maxSupply
    )
        external
        fragmentOwnerOnly(fragmentHash)
        returns (address entity, address vault)
    {
        {
            IUtility ut = IUtility(getUtilityLibrary());

            // create a unique entity contract based on this fragment
            entity = Create2.deploy(
                0,
                keccak256(
                    abi.encodePacked(
                        fragmentHash,
                        tokenName,
                        tokenSymbol,
                        uint8(0xE)
                    )
                ),
                ut.getRezProxyBytecode()
            );

            // create a unique vault contract based on this fragment
            vault = Create2.deploy(
                0,
                keccak256(
                    abi.encodePacked(
                        fragmentHash,
                        tokenName,
                        tokenSymbol,
                        uint8(0xF)
                    )
                ),
                ut.getRezProxyBytecode()
            );
        }

        // entity
        {
            // immediately initialize
            IRezProxy(payable(entity)).bootstrapProxy(
                getAddress(SLOT_entityLogic)
            );

            FragmentInitData memory params = FragmentInitData(
                fragmentHash,
                maxSupply,
                address(this),
                payable(vault), // Functions and addresses declared payable can receive ether into the contract. (https://solidity-by-example.org/payable/)
                unique,
                updateable
            );

            IEntity(entity).bootstrap(tokenName, tokenSymbol, params);

            // keep track of this new contract
            EnumerableSet.AddressSet[1] storage s;
            bytes32 slot = bytes32(
                uint256(
                    keccak256(abi.encodePacked(FRAGMENT_ENTITIES, fragmentHash))
                )
            );
            assembly {
                s.slot := slot
            }
            s[0].add(entity);
        }

        // vault
        {
            // immediately initialize
            IRezProxy(payable(vault)).bootstrapProxy(
                getAddress(SLOT_vaultLogic)
            );
            IVault(payable(vault)).bootstrap(entity, address(this));
        }

        // emit events
        emit Rez(fragmentHash, entity, vault);
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
    function banish(uint160[] memory fragmentHash) external onlyOwner {
        for (uint256 i = 0; i < fragmentHash.length; i++) {
            _burn(fragmentHash[i]);
        }
    }

    /*
        Useful to remove spam and abuse of the system.
        Notice that referencing works will still work! We on purpose don't clean up data for now.
        Even staking and all still works.
        This literally just removes the ability to trade it and removes it from showing on portals like OpenSea.
    */
    function burn(uint160 fragmentHash)
        external
        fragmentOwnerOnly(fragmentHash)
    {
        _burn(fragmentHash);
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
