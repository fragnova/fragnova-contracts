pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "./HastenNFT.sol";
import "./Utility.sol";
import "./Flushable.sol";

struct StakeData {
    uint256 amount;
    uint256 blockStart;
    uint256 blockUnlock;
}

// this contract uses proxy
contract HastenScript is HastenNFT, Initializable, Flushable {
    uint8 private constant mutableVersion = 0x1;
    uint8 private constant immutableVersion = 0x1;
    uint8 private constant extraStorageVersion = 0x1;

    using SafeERC20 for IERC20;

    event Updated(uint256 indexed tokenId);
    // sidechain will listen to those and allow storage allocations
    event StorageAdd(
        uint256 indexed tokenId,
        address indexed owner,
        uint8 storageVersion,
        bytes32 cid,
        uint64 size
    );
    // sidechain will listen to those, side chain deals with rewards allocations etc
    event Stake(uint256 indexed tokenId, address indexed owner, uint256 amount);

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
        ERC721("Hasten Script v0 NFT", "CODE")
        Ownable(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974))
    {
        // NOT INVOKED IF PROXIED
    }

    function bootstrap() public payable initializer {
        // Ownable
        Ownable._bootstrap(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974));
        // ERC721
        _name = "Hasten Script v0 NFT";
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
            "HastenScript: URI query for nonexistent token"
        );

        bytes memory b58id = new bytes(32);
        bytes32 data = bytes32(tokenId);
        for (uint256 i = 0; i < 32; i++) {
            b58id[i] = data[i];
        }

        return string(abi.encodePacked(_metatataBase, Utility.toBase58(b58id)));
    }

    function dataOf(uint160 scriptHash)
        public
        view
        returns (bytes memory immutableData, bytes memory mutableData)
    {
        return (_immutable[scriptHash], _mutable[scriptHash]);
    }

    function referencesOf(uint160 scriptHash)
        public
        view
        returns (uint160[] memory packedRefs)
    {
        return _references[scriptHash];
    }

    function includeCostOf(uint160 scriptHash)
        public
        view
        returns (uint256 cost)
    {
        return _includeCost[scriptHash];
    }

    function stakeOf(address staker, uint160 scriptHash)
        public
        view
        returns (uint256 cost)
    {
        return _stakedAddrToAmount[staker][scriptHash].amount;
    }

    function stake(uint160 scriptHash, uint256 amount) public {
        assert(address(_daoToken) != address(0));
        uint256 balance = _daoToken.balanceOf(msg.sender);
        require(balance >= amount, "HastenScript: Not enough tokens to stake");
        _stakedAddrToAmount[msg.sender][scriptHash].amount += amount;
        _stakedAddrToAmount[msg.sender][scriptHash].blockStart = block.number;
        _stakedAddrToAmount[msg.sender][scriptHash].blockUnlock =
            block.number +
            _stakeLock;
        emit Stake(
            scriptHash,
            msg.sender,
            _stakedAddrToAmount[msg.sender][scriptHash].amount
        );
        _daoToken.safeTransferFrom(msg.sender, address(this), amount);
    }

    function unstake(uint160 scriptHash) public {
        assert(address(_daoToken) != address(0));
        // find amount
        uint256 amount = _stakedAddrToAmount[msg.sender][scriptHash].amount;
        assert(amount > 0);
        // require lock time
        require(
            block.number >=
                _stakedAddrToAmount[msg.sender][scriptHash].blockUnlock,
            "HastenScript: Cannot unstake yet"
        );
        // reset data
        _stakedAddrToAmount[msg.sender][scriptHash].amount = 0;
        _stakedAddrToAmount[msg.sender][scriptHash].blockStart = 0;
        _stakedAddrToAmount[msg.sender][scriptHash].blockUnlock = 0;
        emit Stake(scriptHash, msg.sender, 0);
        _daoToken.safeTransferFrom(address(this), msg.sender, amount);
    }

    function upload(
        bytes calldata scriptBytes,
        bytes calldata environment,
        uint160[] calldata references,
        bytes32[] calldata storageCids,
        uint64[] calldata storageSizes,
        uint256 includeCost
    ) public {
        assert(storageSizes.length == storageCids.length);

        // mint a new token and upload it
        // but make scripts unique by hashing them
        uint160 hash =
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            scriptBytes,
                            references,
                            storageCids,
                            storageSizes
                        )
                    )
                )
            );

        require(!_exists(hash), "HastenScript: script already minted");

        _mint(msg.sender, hash);

        _immutable[hash] = abi.encodePacked(immutableVersion, scriptBytes);

        if (environment.length > 0) {
            _mutable[hash] = abi.encodePacked(mutableVersion, environment);
        } else {
            _mutable[hash] = abi.encodePacked(mutableVersion);
        }

        if (storageSizes.length > 0) {
            // Pay for storage
            uint256 balance = 0;
            if (address(_daoToken) != address(0)) {
                balance = _daoToken.balanceOf(msg.sender);
            }

            uint256 required = 0;
            for (uint256 i = 0; i < storageSizes.length; i++) {
                emit StorageAdd(
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
                    "HastenScript: not enough balance to store assets"
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
                    "HastenScript: not enough staked amount to reference script"
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
        uint160 scriptHash,
        bytes calldata environment,
        uint256 includeCost
    ) public {
        require(
            _exists(scriptHash) && msg.sender == ownerOf(scriptHash),
            "HastenScript: Only the owner of the script can update it"
        );

        _mutable[scriptHash] = abi.encodePacked(mutableVersion, environment);

        _includeCost[scriptHash] = includeCost;

        emit Updated(scriptHash);
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
