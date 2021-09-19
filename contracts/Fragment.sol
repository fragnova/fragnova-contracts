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

struct StakeDataV0 {
    uint256 amount;
    uint256 blockStart;
    uint256 blockUnlock;
}

struct FragmentDataV0 {
    uint256 includeCost;
    bytes32 mutableDataHash;
    // Knowing the block we can restore the transaction even from a simple full node
    // web3.eth.getBlock(blockNumber, true) - will uncompress transactions!
    uint64 iDataBlockNumber; // immutable data
    uint64 mDataBlockNumber; // mutable data
}

// this contract uses proxy
contract Fragment is
    ERC721Enumerable,
    Ownable,
    Initializable,
    RoyaltiesReceiver
{
    string private constant _NAME = "Fragments of The Metaverse";
    string private constant _SYMBOL = "FRAGs";

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
    bytes32 private constant SLOT_byteCost =
        bytes32(uint256(keccak256("fragcolor.fragment.byteCost")) - 1);
    bytes32 private constant SLOT_stakeLock =
        bytes32(uint256(keccak256("fragcolor.fragment.stakeLock")) - 1);
    bytes32 private constant SLOT_entityLogic =
        bytes32(uint256(keccak256("fragcolor.fragment.entityLogic")) - 1);
    bytes32 private constant SLOT_vaultLogic =
        bytes32(uint256(keccak256("fragcolor.fragment.vaultLogic")) - 1);
    bytes32 private constant SLOT_utilityToken =
        bytes32(uint256(keccak256("fragcolor.fragment.utilityToken")) - 1);
    bytes32 private constant SLOT_utilityLibrary =
        bytes32(uint256(keccak256("fragcolor.fragment.utilityLibrary")) - 1);
    bytes32 private constant SLOT_controller =
        bytes32(uint256(keccak256("fragcolor.fragment.controller")) - 1);
    bytes32 private constant SLOT_ipfsRuntime =
        bytes32(uint256(keccak256("fragcolor.fragment.ipfsRuntime")) - 1);

    // just prefixes as we need to map
    bytes32 private constant FRAGMENT_REFS =
        keccak256("fragcolor.fragment.referencing");
    // layering whitelisting
    bytes32 private constant FRAGMENT_WHITELIST =
        keccak256("fragcolor.fragment.referencing");
    // keep track of rezzed entitites
    bytes32 private constant FRAGMENT_ENTITIES =
        keccak256("fragcolor.fragment.entities");
    bytes32 private constant FRAGMENT_DATA_V0 =
        keccak256("fragcolor.fragment.v0");
    // address to token to data map(map)
    bytes32 private constant FRAGMENT_STAKE_A2T2D_V0 =
        keccak256("fragcolor.fragment.a2t2d.v0");
    // map token -> stakers set
    bytes32 private constant FRAGMENT_STAKE_T2A_V0 =
        keccak256("fragcolor.fragment.t2a.v0");

    constructor()
        ERC721(_NAME, _SYMBOL)
        Ownable(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974))
    {
        // NOT INVOKED IF PROXIED
        _setStakeLock(23500);
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
        // ERC721
        _name = _NAME;
        _symbol = _SYMBOL;
        // Others
        _setStakeLock(23500);
        _setController(owner());
        _setUtilityLibrary(address(0x87A26d575DA6d8e2993EAD77f8f6CD12CAd361bC));
        _setEntityLogic(address(0x13cdfE384D63D4D4634250dF643629E01D3E6540));
        _setVaultLogic(address(0xA439872b04aD580d9D573E41fD28a693B4B97515));
        setupRoyalties(payable(owner()), FRAGMENT_ROYALTIES_BPS);
    }

    /*
        GET Storage costs in $FRAG
    */
    function getByteCost() public view returns (uint256 cost) {
        bytes32 slot = SLOT_byteCost;
        assembly {
            cost := sload(slot)
        }
    }

    /*
        SET Storage costs in $FRAG
    */
    function setByteCost(uint256 cost) public onlyOwner {
        bytes32 slot = SLOT_byteCost;
        assembly {
            sstore(slot, cost)
        }
    }

    /*
        GET time in blocks of stake lock
    */
    function getStakeLock() public view returns (uint256 time) {
        bytes32 slot = SLOT_stakeLock;
        assembly {
            time := sload(slot)
        }
    }

    function _setStakeLock(uint256 time) private {
        bytes32 slot = SLOT_stakeLock;
        assembly {
            sstore(slot, time)
        }
    }

    /*
        SET time in blocks of stake lock
    */
    function setStakeLock(uint256 time) public onlyOwner {
        _setStakeLock(time);
    }

    /*
        GET Entity logic contract
    */
    function getEntityLogic() public view returns (address addr) {
        bytes32 slot = SLOT_entityLogic;
        assembly {
            addr := sload(slot)
        }
    }

    function _setEntityLogic(address addr) private {
        bytes32 slot = SLOT_entityLogic;
        assembly {
            sstore(slot, addr)
        }
    }

    /*
        SET Entity logic contract
    */
    function setEntityLogic(address addr) public onlyOwner {
        _setEntityLogic(addr);
    }

    function getUtilityToken() public view returns (address addr) {
        bytes32 slot = SLOT_utilityToken;
        assembly {
            addr := sload(slot)
        }
    }

    function _setUtilityToken(address addr) private {
        bytes32 slot = SLOT_utilityToken;
        assembly {
            sstore(slot, addr)
        }
    }

    function setUtilityToken(address addr) public onlyOwner {
        _setUtilityToken(addr);
    }

    function getUtilityLibrary() public view returns (address addr) {
        bytes32 slot = SLOT_utilityLibrary;
        assembly {
            addr := sload(slot)
        }
    }

    function _setUtilityLibrary(address addr) private {
        bytes32 slot = SLOT_utilityLibrary;
        assembly {
            sstore(slot, addr)
        }
    }

    function setUtilityLibrary(address addr) public onlyOwner {
        _setUtilityLibrary(addr);
    }

    function getVaultLogic() public view returns (address addr) {
        bytes32 slot = SLOT_vaultLogic;
        assembly {
            addr := sload(slot)
        }
    }

    function _setVaultLogic(address addr) private {
        bytes32 slot = SLOT_vaultLogic;
        assembly {
            sstore(slot, addr)
        }
    }

    function setVaultLogic(address addr) public onlyOwner {
        _setVaultLogic(addr);
    }

    function getController() public view returns (address addr) {
        bytes32 slot = SLOT_controller;
        assembly {
            addr := sload(slot)
        }
    }

    function _setController(address addr) private {
        bytes32 slot = SLOT_controller;
        assembly {
            sstore(slot, addr)
        }
    }

    function setController(address addr) public onlyOwner {
        _setController(addr);
    }

    /* runtime CID/Hash on chain is important to ensure it's genuine */

    function getIpfsRuntime() public view returns (bytes32 cid) {
        bytes32 slot = SLOT_ipfsRuntime;
        assembly {
            cid := sload(slot)
        }
    }

    function setIpfsRuntime(bytes32 cid) public onlyOwner {
        bytes32 slot = SLOT_ipfsRuntime;
        assembly {
            sstore(slot, cid)
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
        (uint64 ib, uint64 mb) = dataOf(fragmentHash);

        return
            ut.buildFragmentMetadata(
                fragmentHash,
                mutableDataHashOf(fragmentHash),
                includeCostOf(fragmentHash),
                uint256(ib),
                uint256(mb)
            );
    }

    function contractURI() public view returns (string memory) {
        IUtility ut = IUtility(getUtilityLibrary());
        return ut.buildFragmentRootMetadata(owner(), FRAGMENT_ROYALTIES_BPS);
    }

    function isReferencedBy(uint160 referenced, uint160 referencer)
        public
        view
        returns (bool)
    {
        EnumerableSet.UintSet[1] storage referencing;
        bytes32 slot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_REFS, referenced)))
        );
        assembly {
            referencing.slot := slot
        }

        return referencing[0].contains(referencer);
    }

    // this can effectively be used to prevent a creator from referecing the fragment
    // keep in mind that an empty whitelist means anyone can reference though!
    function whitelistRemove(uint160 fragmentHash, address referencer)
        public
        fragmentOwnerOnly(fragmentHash)
    {
        EnumerableSet.AddressSet[1] storage referencing;
        bytes32 slot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_WHITELIST, fragmentHash))
            )
        );
        assembly {
            referencing.slot := slot
        }

        referencing[0].remove(referencer);
    }

    // this can effectively be used to whitelist a creator from referecing the fragment
    function whitelistAdd(uint160 fragmentHash, address referencer)
        public
        fragmentOwnerOnly(fragmentHash)
    {
        EnumerableSet.AddressSet[1] storage referencing;
        bytes32 slot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_WHITELIST, fragmentHash))
            )
        );
        assembly {
            referencing.slot := slot
        }

        referencing[0].add(referencer);
    }

    function includeCostOf(uint160 fragmentHash)
        public
        view
        returns (uint256 cost)
    {
        FragmentDataV0[1] storage data;
        bytes32 dslot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_DATA_V0, fragmentHash)))
        );
        assembly {
            data.slot := dslot
        }

        return data[0].includeCost;
    }

    function mutableDataHashOf(uint160 fragmentHash)
        public
        view
        returns (bytes32)
    {
        FragmentDataV0[1] storage data;
        bytes32 dslot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_DATA_V0, fragmentHash)))
        );
        assembly {
            data.slot := dslot
        }

        return data[0].mutableDataHash;
    }

    function dataOf(uint160 fragmentHash)
        public
        view
        returns (uint64 immutableData, uint64 mutableData)
    {
        FragmentDataV0[1] storage data;
        bytes32 dslot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_DATA_V0, fragmentHash)))
        );
        assembly {
            data.slot := dslot
        }

        return (data[0].iDataBlockNumber, data[0].mDataBlockNumber);
    }

    function stakeOf(uint160 fragmentHash, address staker)
        public
        view
        returns (uint256 amount, uint256 blockStart)
    {
        StakeDataV0[1] storage data;
        bytes32 slot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(
                        FRAGMENT_STAKE_A2T2D_V0,
                        staker,
                        fragmentHash
                    )
                )
            )
        );
        assembly {
            data.slot := slot
        }

        return (data[0].amount, data[0].blockStart);
    }

    function getStakeAt(uint160 fragmentHash, uint256 index)
        public
        view
        returns (address staker, uint256 amount)
    {
        EnumerableSet.AddressSet[1] storage s;
        bytes32 sslot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_STAKE_T2A_V0, fragmentHash))
            )
        );
        assembly {
            s.slot := sslot
        }

        staker = s[0].at(index);
        StakeDataV0[1] storage data;
        bytes32 slot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(
                        FRAGMENT_STAKE_A2T2D_V0,
                        staker,
                        fragmentHash
                    )
                )
            )
        );
        assembly {
            data.slot := slot
        }
        amount = data[0].amount;
    }

    function getStakeCount(uint160 fragmentHash) public view returns (uint256) {
        EnumerableSet.AddressSet[1] storage s;
        bytes32 sslot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_STAKE_T2A_V0, fragmentHash))
            )
        );
        assembly {
            s.slot := sslot
        }

        return s[0].length();
    }

    function stake(uint160 fragmentHash, uint256 amount) public {
        IERC20 ut = IERC20(getUtilityToken());
        assert(address(ut) != address(0));

        uint256 balance = ut.balanceOf(msg.sender);
        require(balance >= amount, "Fragment: not enough tokens to stake");

        StakeDataV0[1] storage data;
        bytes32 slot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(
                        FRAGMENT_STAKE_A2T2D_V0,
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
        data[0].blockUnlock = block.number + getStakeLock();

        EnumerableSet.AddressSet[1] storage adata;
        bytes32 aslot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_STAKE_T2A_V0, fragmentHash))
            )
        );
        assembly {
            adata.slot := aslot
        }

        adata[0].add(msg.sender);

        emit Stake(fragmentHash, msg.sender, data[0].amount);

        ut.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint160 fragmentHash) public {
        IERC20 ut = IERC20(getUtilityToken());
        assert(address(ut) != address(0));

        StakeDataV0[1] storage data;
        bytes32 slot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(
                        FRAGMENT_STAKE_A2T2D_V0,
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
                keccak256(abi.encodePacked(FRAGMENT_STAKE_T2A_V0, fragmentHash))
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
        public
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
        public
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

    function upload(
        bytes calldata immutableData, // immutable
        bytes calldata mutableData, // mutable
        uint160[] calldata references, // immutable
        uint256 includeCost // mutable
    ) public {
        // mint a new token and upload it
        // but make fragments unique by hashing them
        // THIS IS THE BIG DEAL
        // Apps just by knowing the hash can verify
        // That references are collected and were verified on upload
        // storageCids loaded are also paid
        uint160 hash = uint160(
            uint256(keccak256(abi.encodePacked(immutableData, references)))
        );

        require(!_exists(hash), "Fragment: fragment already minted");

        _mint(msg.sender, hash);

        bytes32 slot = 0;

        if (references.length > 0) {
            uint256 stakeLock = getStakeLock();
            for (uint256 i = 0; i < references.length; i++) {
                // We always can include our own creations
                uint160 referenced = references[i];
                if (ownerOf(referenced) == msg.sender) continue;

                FragmentDataV0[1] storage fdata;
                slot = bytes32(
                    uint256(
                        keccak256(
                            abi.encodePacked(
                                FRAGMENT_DATA_V0,
                                uint160(referenced)
                            )
                        )
                    )
                );
                assembly {
                    fdata.slot := slot
                }

                {
                    StakeDataV0[1] storage sdata;
                    slot = bytes32(
                        uint256(
                            keccak256(
                                abi.encodePacked(
                                    FRAGMENT_STAKE_A2T2D_V0,
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
                        "Fragment: not enough staked amount to reference fragment"
                    );

                    // lock the stake for a new period
                    sdata[0].blockUnlock = block.number + stakeLock;
                }

                EnumerableSet.AddressSet[1] storage whitelist;
                slot = bytes32(
                    uint256(
                        keccak256(
                            abi.encodePacked(FRAGMENT_WHITELIST, referenced)
                        )
                    )
                );
                assembly {
                    whitelist.slot := slot
                }
                require(
                    whitelist[0].length() == 0 ||
                        whitelist[0].contains(msg.sender),
                    "Fragment: creator not whitelisted"
                );

                EnumerableSet.UintSet[1] storage referencing;
                slot = bytes32(
                    uint256(
                        keccak256(abi.encodePacked(FRAGMENT_REFS, referenced))
                    )
                );
                assembly {
                    referencing.slot := slot
                }

                // also add this newly minted fragment to the referencing list
                referencing[0].add(hash);
            }
        }

        FragmentDataV0[1] storage data;
        slot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_DATA_V0, hash)))
        );
        assembly {
            data.slot := slot
        }

        data[0] = FragmentDataV0(
            includeCost,
            keccak256(mutableData),
            uint64(block.number),
            0 // first upload, no mutation
        );
    }

    function update(
        uint160 fragmentHash,
        bytes calldata mutableData,
        uint256 includeCost
    ) public fragmentOwnerOnly(fragmentHash) {
        (uint64 blockNumber, ) = dataOf(fragmentHash);

        FragmentDataV0[1] storage data;
        bytes32 dslot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_DATA_V0, fragmentHash)))
        );
        assembly {
            data.slot := dslot
        }

        data[0] = FragmentDataV0(
            includeCost,
            keccak256(mutableData),
            blockNumber, // don't overwrite this
            uint64(block.number) // this also marks it as mutated - if not would be 0
        );

        emit Update(fragmentHash);
    }

    function rez(
        uint160 fragmentHash,
        string calldata tokenName,
        string calldata tokenSymbol,
        bool unique,
        bool updateable,
        uint96 maxSupply
    )
        public
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
            IRezProxy(payable(entity)).bootstrapProxy(getEntityLogic());

            FragmentInitData memory params = FragmentInitData(
                fragmentHash,
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
            IRezProxy(payable(vault)).bootstrapProxy(getVaultLogic());
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
    function banish(uint160[] memory fragmentHash) public onlyOwner {
        for (uint256 i = 0; i < fragmentHash.length; i++) {
            _burn(fragmentHash[i]);
        }
    }
}
