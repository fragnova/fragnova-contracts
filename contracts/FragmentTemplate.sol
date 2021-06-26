pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-solidity/contracts/utils/Create2.sol";
import "./FragmentNFT.sol";
import "./FragmentEntityProxy.sol";
import "./FragmentEntity.sol";
import "./Utility.sol";

struct StakeDataV0 {
    uint256 amount;
    uint256 blockStart;
    uint256 blockUnlock;
}

struct FragmentDataV0 {
    bytes32 ipfsCacheDirectory;
    uint256 includeCost;
    bytes32 environmentHash;
}

// this contract uses proxy
contract FragmentTemplate is IFragmentTemplate, FragmentNFT, Initializable {
    uint8 private constant calldataVersion = 0x1;
    uint8 private constant extraStorageVersion = 0x1;

    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    // sidechains can use this to upload data
    event Upload(
        uint256 indexed tokenId,
        uint8 version,
        bytes templateBytes,
        bytes environment
    );

    // mutable part updated
    event Update(uint256 indexed tokenId, uint8 version, bytes environment);

    // sidechain will listen to those and allow storage allocations
    event Store(
        uint256 indexed tokenId,
        address indexed owner,
        uint8 storageVersion,
        bytes32 cid,
        uint64 size
    );

    // sidechain will listen to those, side chain deals with rewards allocations etc
    event Stake(uint256 indexed tokenId, address indexed owner, uint256 amount);

    // a new wild entity appeared on the grid
    // this is necessary to make the link with the sidechain
    event Rez(uint256 indexed tokenId, address newContract);

    // Unstructured storage slots
    bytes32 private constant SLOT_byteCost =
        bytes32(uint256(keccak256("fragcolor.fragment.byteCost")) - 1);
    bytes32 private constant SLOT_stakeLock =
        bytes32(uint256(keccak256("fragcolor.fragment.stakeLock")) - 1);
    bytes32 private constant SLOT_entityLogic =
        bytes32(uint256(keccak256("fragcolor.fragment.entityLogic")) - 1);

    // just prefixes as we need to map
    bytes32 private constant FRAGMENT_REFS =
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
        ERC721("Fragments v0 NFT", "FRAGs")
        Ownable(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974))
    {
        // NOT INVOKED IF PROXIED
        _setStakeLock(23500);
    }

    function bootstrap() public payable initializer {
        // Ownable
        Ownable._bootstrap(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974));
        // ERC721
        _name = "Fragments v0 NFT";
        _symbol = "FRAGs";
        _setStakeLock(23500);
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

    /*
        SET time in blocks of stake lock
    */
    function _setStakeLock(uint256 time) private {
        bytes32 slot = SLOT_stakeLock;
        assembly {
            sstore(slot, time)
        }
    }

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

    /*
        SET Entity logic contract
    */
    function setEntityLogic(address addr) public onlyOwner {
        bytes32 slot = SLOT_entityLogic;
        assembly {
            sstore(slot, addr)
        }
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "FragmentTemplate: URI query for nonexistent token"
        );

        FragmentDataV0[1] storage data;
        bytes32 dslot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_DATA_V0, uint160(tokenId)))
            )
        );
        assembly {
            data.slot := dslot
        }

        return
            string(
                abi.encodePacked(
                    "ipfs://",
                    Utility.toBase58(
                        // multihash headers: uint8(0x12), uint8(0x20)
                        abi.encodePacked(
                            uint8(0x12),
                            uint8(0x20),
                            data[0].ipfsCacheDirectory
                        ),
                        46
                    ),
                    "/metadata.json"
                )
            );
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

    function includeCostOf(uint160 templateHash)
        public
        view
        returns (uint256 cost)
    {
        FragmentDataV0[1] storage data;
        bytes32 dslot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(FRAGMENT_DATA_V0, uint160(templateHash))
                )
            )
        );
        assembly {
            data.slot := dslot
        }

        return data[0].includeCost;
    }

    function environmentHashOf(uint160 templateHash)
        public
        view
        returns (bytes32)
    {
        FragmentDataV0[1] storage data;
        bytes32 dslot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(FRAGMENT_DATA_V0, uint160(templateHash))
                )
            )
        );
        assembly {
            data.slot := dslot
        }

        return data[0].environmentHash;
    }

    function stakeOf(address staker, uint160 templateHash)
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
                        templateHash
                    )
                )
            )
        );
        assembly {
            data.slot := slot
        }

        return (data[0].amount, data[0].blockStart);
    }

    function stake(uint160 templateHash, uint256 amount) public {
        uint256 balance = _utilityToken.balanceOf(msg.sender);
        require(
            balance >= amount,
            "FragmentTemplate: not enough tokens to stake"
        );

        StakeDataV0[1] storage data;
        bytes32 slot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(
                        FRAGMENT_STAKE_A2T2D_V0,
                        msg.sender,
                        templateHash
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
                keccak256(abi.encodePacked(FRAGMENT_STAKE_T2A_V0, templateHash))
            )
        );
        assembly {
            adata.slot := aslot
        }

        adata[0].add(msg.sender);

        emit Stake(templateHash, msg.sender, data[0].amount);

        _utilityToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint160 templateHash) public {
        assert(address(_utilityToken) != address(0));

        StakeDataV0[1] storage data;
        bytes32 slot = bytes32(
            uint256(
                keccak256(
                    abi.encodePacked(
                        FRAGMENT_STAKE_A2T2D_V0,
                        msg.sender,
                        templateHash
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
            "FragmentTemplate: cannot unstake yet"
        );
        // reset data
        data[0].amount = 0;
        data[0].blockStart = 0;
        data[0].blockUnlock = 0;

        EnumerableSet.AddressSet[1] storage adata;
        bytes32 aslot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_STAKE_T2A_V0, templateHash))
            )
        );
        assembly {
            adata.slot := aslot
        }

        adata[0].remove(msg.sender);

        emit Stake(templateHash, msg.sender, 0);

        _utilityToken.safeTransfer(msg.sender, amount);
    }

    function getStakers(uint160 templateHash)
        public
        view
        returns (address[] memory stakers, uint256[] memory amounts)
    {
        EnumerableSet.AddressSet[1] storage s;
        bytes32 sslot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_STAKE_T2A_V0, templateHash))
            )
        );
        assembly {
            s.slot := sslot
        }

        uint256 len = s[0].length();
        stakers = new address[](len);
        amounts = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            stakers[i] = s[0].at(i);
            StakeDataV0[1] storage data;
            bytes32 slot = bytes32(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            FRAGMENT_STAKE_A2T2D_V0,
                            stakers[i],
                            templateHash
                        )
                    )
                )
            );
            assembly {
                data.slot := slot
            }
            amounts[i] = data[0].amount;
        }
    }

    function getEntities(uint160 templateHash)
        public
        view
        returns (address[] memory entities)
    {
        EnumerableSet.AddressSet[1] storage s;
        bytes32 slot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_ENTITIES, templateHash))
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

    function upload(
        bytes calldata templateBytes,
        bytes calldata environment,
        bytes32 cacheDirectoryCid,
        uint160[] calldata references,
        bytes32[] calldata storageCids,
        uint64[] calldata storageSizes,
        uint256 includeCost
    ) public {
        assert(storageSizes.length == storageCids.length);

        // mint a new token and upload it
        // but make templates unique by hashing them
        uint160 hash = uint160(
            uint256(
                keccak256(
                    abi.encodePacked(
                        templateBytes,
                        references,
                        storageCids,
                        storageSizes
                    )
                )
            )
        );

        require(!_exists(hash), "FragmentTemplate: template already minted");

        _mint(msg.sender, hash);

        emit Upload(hash, calldataVersion, templateBytes, environment);

        if (storageSizes.length > 0) {
            // Pay for storage
            uint256 balance = _utilityToken.balanceOf(msg.sender);
            uint256 required = 0;
            uint256 byteCost = getByteCost();
            for (uint256 i = 0; i < storageSizes.length; i++) {
                emit Store(
                    hash,
                    msg.sender,
                    extraStorageVersion,
                    storageCids[i],
                    storageSizes[i]
                );
                required += storageSizes[i] * byteCost;
            }

            if (required > 0) {
                require(
                    balance >= required,
                    "FragmentTemplate: not enough balance to store assets"
                );
                _utilityToken.safeTransferFrom(msg.sender, owner(), required);
            }
        }

        if (references.length > 0) {
            uint256 stakeLock = getStakeLock();
            for (uint256 i = 0; i < references.length; i++) {
                // We always can include our own creations
                uint160 referenced = references[i];
                if (ownerOf(referenced) == msg.sender) continue;

                StakeDataV0[1] storage sdata;
                bytes32 sslot = bytes32(
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
                    sdata.slot := sslot
                }

                // Not ours, verify how much we staked on it
                uint256 cost = includeCostOf(referenced);
                uint256 stakeAmount = sdata[0].amount;

                require(
                    stakeAmount >= cost,
                    "FragmentTemplate: not enough staked amount to reference template"
                );

                // lock the stake for a new period
                sdata[0].blockUnlock = block.number + stakeLock;

                EnumerableSet.UintSet[1] storage referencing;
                bytes32 slot = bytes32(
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
        bytes32 dslot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_DATA_V0, hash)))
        );
        assembly {
            data.slot := dslot
        }
        data[0] = FragmentDataV0(
            cacheDirectoryCid,
            includeCost,
            keccak256(environment)
        );
    }

    function update(
        uint160 templateHash,
        bytes calldata environment,
        bytes32 cacheDirectoryCid,
        uint256 includeCost
    ) public {
        require(
            _exists(templateHash) && msg.sender == ownerOf(templateHash),
            "FragmentTemplate: only the owner of the template can update it"
        );

        FragmentDataV0[1] storage data;
        bytes32 dslot = bytes32(
            uint256(keccak256(abi.encodePacked(FRAGMENT_DATA_V0, templateHash)))
        );
        assembly {
            data.slot := dslot
        }
        data[0] = FragmentDataV0(
            cacheDirectoryCid,
            includeCost,
            keccak256(environment)
        );

        emit Update(templateHash, calldataVersion, environment);
    }

    function _beforeTokenTransfer(
        address from,
        address,
        uint256
    ) internal pure override {
        // prevent transferring, for now templates are no transfer
        // this is to avoid security classification, in the future
        // the DAO might decide to remove this limit
        require(
            from == address(0),
            "FragmentTemplate: cannot transfer templates"
        );
    }

    function rez(
        uint160 templateHash,
        string calldata tokenName,
        string calldata tokenSymbol
    ) public returns (address) {
        require(
            _exists(templateHash) && msg.sender == ownerOf(templateHash),
            "FragmentTemplate: only the owner of the template can rez it"
        );
        // create a unique entity contract based on this template
        address newContract = Create2.deploy(
            0,
            keccak256(abi.encodePacked(templateHash, tokenName, tokenSymbol)),
            type(FragmentEntityProxy).creationCode
        );
        // immediately initialize
        FragmentEntityProxy(payable(newContract)).bootstrapProxy(
            getEntityLogic()
        );
        FragmentEntity(newContract).bootstrap(
            tokenName,
            tokenSymbol,
            templateHash,
            address(this)
        );

        // keep track of this new contract
        EnumerableSet.AddressSet[1] storage s;
        bytes32 slot = bytes32(
            uint256(
                keccak256(abi.encodePacked(FRAGMENT_ENTITIES, templateHash))
            )
        );
        assembly {
            s.slot := slot
        }
        s[0].add(newContract);

        // emit event
        emit Rez(templateHash, newContract);

        return newContract;
    }

    function getVault() public view override returns (address payable) {
        return payable(owner());
    }
}
