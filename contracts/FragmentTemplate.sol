pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "./FragmentNFT.sol";
import "./Utility.sol";
import "./Flushable.sol";

struct StakeData {
    uint256 amount;
    uint256 blockStart;
    uint256 blockUnlock;
}

// this contract uses proxy
contract FragmentTemplate is FragmentNFT, Initializable, Flushable {
    uint8 private constant mutableVersion = 0x1;
    uint8 private constant immutableVersion = 0x1;
    uint8 private constant extraStorageVersion = 0x1;

    using SafeERC20 for IERC20;

    event Updated(uint256 indexed tokenId);
    // sidechain will listen to those and allow storage allocations
    event Stored(
        uint256 indexed tokenId,
        address indexed owner,
        uint8 storageVersion,
        bytes32 cid,
        uint64 size
    );
    // sidechain will listen to those, side chain deals with rewards allocations etc
    event Staked(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 amount
    );

    uint256 internal _byteCost = 0;

    // Actual brotli compressed edn code/data
    mapping(uint256 => bytes) internal _immutable;
    mapping(uint256 => bytes) internal _mutable;

    // Other on-chain references
    mapping(uint256 => uint160[]) internal _references;

    // How much staking is needed to include this fragment
    mapping(uint256 => uint256) internal _includeCost;
    // Actual amount staked on this fragment
    mapping(address => mapping(uint256 => StakeData))
        internal _stakedAddrToAmount;
    // Number of blocks to lock the stake after an action
    uint256 internal _stakeLock = 23500; // about half a week

    // decrease that number to consume a slot in the future
    uint256[32] _reservedSlots;

    constructor()
        ERC721("Fragment Template v0 NFT", "CODE")
        Ownable(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974))
    {
        // NOT INVOKED IF PROXIED
    }

    function bootstrap() public payable initializer {
        // Ownable
        Ownable._bootstrap(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974));
        // ERC721
        _name = "Fragment Template v0 NFT";
        _symbol = "CODE";
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

        bytes memory b58id = new bytes(32);
        bytes32 data = bytes32(tokenId);
        for (uint256 i = 0; i < 32; i++) {
            b58id[i] = data[i];
        }

        return string(abi.encodePacked(_metatataBase, Utility.toBase58(b58id)));
    }

    function dataOf(uint160 templateHash)
        public
        view
        returns (bytes memory immutableData, bytes memory mutableData)
    {
        return (_immutable[templateHash], _mutable[templateHash]);
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
        returns (uint256 cost)
    {
        return _stakedAddrToAmount[staker][templateHash].amount;
    }

    function stake(uint160 templateHash, uint256 amount) public {
        uint256 balance = _daoToken.balanceOf(msg.sender);
        require(balance >= amount, "FragmentTemplate: not enough tokens to stake");
        // sum it as users might add more tokens to the stake
        _stakedAddrToAmount[msg.sender][templateHash].amount += amount;
        _stakedAddrToAmount[msg.sender][templateHash].blockStart = block.number;
        _stakedAddrToAmount[msg.sender][templateHash].blockUnlock =
            block.number +
            _stakeLock;
        emit Staked(
            templateHash,
            msg.sender,
            _stakedAddrToAmount[msg.sender][templateHash].amount
        );
        _daoToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint160 templateHash) public {
        assert(address(_daoToken) != address(0));
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
        emit Staked(templateHash, msg.sender, 0);
        _daoToken.safeTransferFrom(address(this), msg.sender, amount);
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

        _immutable[hash] = abi.encodePacked(immutableVersion, templateBytes);

        if (environment.length > 0) {
            _mutable[hash] = abi.encodePacked(mutableVersion, environment);
        } else {
            _mutable[hash] = abi.encodePacked(mutableVersion);
        }

        if (storageSizes.length > 0) {
            // Pay for storage
            uint256 balance = _daoToken.balanceOf(msg.sender);
            uint256 required = 0;
            for (uint256 i = 0; i < storageSizes.length; i++) {
                emit Stored(
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
                _daoToken.safeTransferFrom(msg.sender, address(this), required);
            }
        }

        if (references.length > 0) {
            _references[hash] = references;
            for (uint256 i = 0; i < references.length; i++) {
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

        _mutable[templateHash] = abi.encodePacked(mutableVersion, environment);

        _includeCost[templateHash] = includeCost;

        emit Updated(templateHash);
    }

    // reward minting
    // limited to once per block for safety reasons
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256
    ) internal override {
        // ensure it is a mint
        if (
            from == address(0) &&
            address(_daoToken) != address(0) &&
            to == msg.sender
        ) {
            if (
                _rewardBlocks[msg.sender] != block.number &&
                _daoToken.balanceOf(address(this)) > _reward
            ) {
                _rewardBlocks[msg.sender] = block.number;
                _daoToken.safeIncreaseAllowance(address(this), _reward);
                _daoToken.safeTransferFrom(address(this), msg.sender, _reward);
            }
        }
    }

    function setMintReward(uint256 amount) public onlyOwner {
        _reward = amount;
    }

    function getMintReward() public view returns (uint256) {
        return _reward;
    }
}
