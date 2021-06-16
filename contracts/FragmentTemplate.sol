pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-solidity/contracts/utils/Create2.sol";
import "./FragmentNFT.sol";
import "./FragmentEntityProxy.sol";
import "./FragmentEntity.sol";
import "./Utility.sol";

struct StakeData {
    uint256 amount;
    uint256 blockStart;
    uint256 blockUnlock;
}

// this contract uses proxy
contract FragmentTemplate is FragmentNFT, Initializable {
    uint8 private constant calldataVersion = 0x1;
    uint8 private constant extraStorageVersion = 0x1;

    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

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

    uint256 private _byteCost = 0;

    // Other on-chain references
    mapping(uint256 => uint160[]) private _references;

    // the amount of $FRAG allocated for rewards
    uint256 private _rewardTotal = 0;

    // How much staking is needed to include this fragment
    mapping(uint256 => uint256) private _includeCost;
    // Actual amount staked on this fragment
    mapping(address => mapping(uint256 => StakeData))
        private _stakedAddrToAmount;
    // map token -> stakers set
    mapping(uint256 => EnumerableSet.AddressSet) private _tokenToStakers;
    // Number of blocks to lock the stake after an action
    uint256 private _stakeLock = 23500; // about half a week

    // FragmentEntity logic contract
    address private _entityLogic = address(0);

    // keep track of rezzed entitites
    mapping(uint256 => EnumerableSet.AddressSet) private _tokenToEntities;

    // decrease that number to consume a slot in the future
    uint256[32] private _reservedSlots;

    constructor()
        ERC721("Fragment Template v0 NFT", "FRAGt")
        Ownable(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974))
    {
        // NOT INVOKED IF PROXIED
    }

    function bootstrap() public payable initializer {
        // Ownable
        Ownable._bootstrap(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974));
        // ERC721
        _name = "Fragment Template v0 NFT";
        _symbol = "FRAGt";
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

        bytes memory b58id = new bytes(20);
        bytes32 data = bytes32(tokenId);
        for (uint256 i = 0; i < 20; i++) {
            b58id[i] = data[i + 12];
        }

        return
            string(
                abi.encodePacked(_metatataBase, Utility.toBase58(b58id, 27))
            );
    }

    function referencesOf(uint160 templateHash)
        public
        view
        returns (uint160[] memory packedRefs)
    {
        return _references[templateHash];
    }

    function includeCostOf(uint160 templateHash)
        public
        view
        returns (uint256 cost)
    {
        return _includeCost[templateHash];
    }

    function stakeOf(address staker, uint160 templateHash)
        public
        view
        returns (uint256 amount, uint256 blockStart)
    {
        return (
            _stakedAddrToAmount[staker][templateHash].amount,
            _stakedAddrToAmount[staker][templateHash].blockStart
        );
    }

    function stake(uint160 templateHash, uint256 amount) public {
        uint256 balance = _utilityToken.balanceOf(msg.sender);
        require(
            balance >= amount,
            "FragmentTemplate: not enough tokens to stake"
        );
        // sum it as users might add more tokens to the stake
        _stakedAddrToAmount[msg.sender][templateHash].amount += amount;
        _stakedAddrToAmount[msg.sender][templateHash].blockStart = block.number;
        _stakedAddrToAmount[msg.sender][templateHash].blockUnlock =
            block.number +
            _stakeLock;
        _tokenToStakers[templateHash].add(msg.sender);
        emit Stake(
            templateHash,
            msg.sender,
            _stakedAddrToAmount[msg.sender][templateHash].amount
        );
        _utilityToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint160 templateHash) public {
        assert(address(_utilityToken) != address(0));
        // find amount
        uint256 amount = _stakedAddrToAmount[msg.sender][templateHash].amount;
        assert(amount > 0);
        // require lock time
        require(
            block.number >=
                _stakedAddrToAmount[msg.sender][templateHash].blockUnlock,
            "FragmentTemplate: cannot unstake yet"
        );
        // reset data
        _stakedAddrToAmount[msg.sender][templateHash].amount = 0;
        _stakedAddrToAmount[msg.sender][templateHash].blockStart = 0;
        _stakedAddrToAmount[msg.sender][templateHash].blockUnlock = 0;
        _tokenToStakers[templateHash].remove(msg.sender);
        emit Stake(templateHash, msg.sender, 0);
        _utilityToken.safeTransfer(msg.sender, amount);
    }

    function getStakers(uint160 templateHash)
        public
        view
        returns (address[] memory stakers, uint256[] memory amounts)
    {
        EnumerableSet.AddressSet storage s = _tokenToStakers[templateHash];
        uint256 len = s.length();
        stakers = new address[](len);
        amounts = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            stakers[i] = s.at(i);
            amounts[i] = _stakedAddrToAmount[stakers[i]][templateHash].amount;
        }
    }

    function getEntities(uint160 templateHash)
        public
        view
        returns (address[] memory entities)
    {
        EnumerableSet.AddressSet storage s = _tokenToEntities[templateHash];
        uint256 len = s.length();
        entities = new address[](len);
        for (uint256 i = 0; i < len; i++) {
            entities[i] = s.at(i);
        }
    }

    function upload(
        bytes calldata templateBytes,
        bytes calldata environment,
        uint160[] calldata references,
        bytes32[] calldata storageCids,
        uint64[] calldata storageSizes,
        uint256 includeCost
    ) public {
        assert(storageSizes.length == storageCids.length);

        // mint a new token and upload it
        // but make templates unique by hashing them
        uint160 hash =
            uint160(
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
            for (uint256 i = 0; i < storageSizes.length; i++) {
                emit Store(
                    hash,
                    msg.sender,
                    extraStorageVersion,
                    storageCids[i],
                    storageSizes[i]
                );
                required += storageSizes[i] * _byteCost;
            }

            if (required > 0) {
                require(
                    balance >= required,
                    "FragmentTemplate: not enough balance to store assets"
                );
                _utilityToken.safeTransferFrom(
                    msg.sender,
                    owner(),
                    required
                );
            }
        }

        if (references.length > 0) {
            _references[hash] = references;
            for (uint256 i = 0; i < references.length; i++) {
                // We always can include our own creations
                if (ownerOf(references[i]) == msg.sender) continue;

                // Not ours, verify how much we staked on it
                uint256 cost = _includeCost[references[i]];
                uint256 stakeAmount =
                    _stakedAddrToAmount[msg.sender][references[i]].amount;
                require(
                    stakeAmount >= cost,
                    "FragmentTemplate: not enough staked amount to reference template"
                );

                // lock the stake for a new period
                _stakedAddrToAmount[msg.sender][references[i]].blockUnlock =
                    block.number +
                    _stakeLock;
            }
        }

        _includeCost[hash] = includeCost;
    }

    function update(
        uint160 templateHash,
        bytes calldata environment,
        uint256 includeCost
    ) public {
        require(
            _exists(templateHash) && msg.sender == ownerOf(templateHash),
            "FragmentTemplate: only the owner of the template can update it"
        );

        _includeCost[templateHash] = includeCost;

        emit Update(templateHash, calldataVersion, environment);
    }

    // reward minting
    // limited to once per block for safety reasons
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        // prevent transferring, for now templates are no transfer
        // this is to avoid security classification, in the future
        // the DAO might decide to remove this limit
        require(
            from == address(0),
            "FragmentTemplate: cannot transfer templates"
        );

        // ensure it is a mint
        if (
            from == address(0) &&
            address(_utilityToken) != address(0) &&
            to == msg.sender
        ) {
            if (
                _rewardBlocks[msg.sender] != block.number &&
                _rewardTotal >= _reward
            ) {
                _rewardBlocks[msg.sender] = block.number;
                _rewardTotal -= _reward;
                _utilityToken.safeIncreaseAllowance(address(this), _reward);
                _utilityToken.safeTransfer(msg.sender, _reward);
            }
        }
    }

    function setMintReward(uint256 amount) public onlyOwner {
        _reward = amount;
    }

    function getMintReward() public view returns (uint256) {
        return _reward;
    }

    function setRewardAllocation(uint256 amount) public onlyOwner {
        // This is dangerous!
        // Make sure to transfer exact amount $FRAG before calling this
        // we should probably use the EIP for transfer and call
        _rewardTotal = amount;
    }

    function setEntityLogic(address entityLogic) public onlyOwner {
        _entityLogic = entityLogic;
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
        address newContract =
            Create2.deploy(
                0,
                keccak256(
                    abi.encodePacked(templateHash, tokenName, tokenSymbol)
                ),
                type(FragmentEntityProxy).creationCode
            );
        // immediately initialize
        FragmentEntityProxy(payable(newContract)).bootstrapProxy(_entityLogic);
        FragmentEntity(newContract).bootstrap(
            tokenName,
            tokenSymbol,
            templateHash,
            address(this)
        );
        // keep track of this new contract
        _tokenToEntities[templateHash].add(newContract);
        // emit event
        emit Rez(templateHash, newContract);
        return newContract;
    }
}
