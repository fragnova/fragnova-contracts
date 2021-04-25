pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "./HastenNFT.sol";
import "./ScriptStorage.sol";
import "./Utility.sol";

// this contract uses proxy, let's keep any storage inside other modules
// this should make it easier to upgrade
contract HastenScript is HastenNFT, Initializable, ScriptStorage {
    uint8 private constant mutableVersion = 0x1;
    uint8 private constant immutableVersion = 0x1;

    using SafeERC20 for IERC20;

    event Updated(uint256 indexed tokenId);

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

        bytes memory ipfsCid = new bytes(32);
        bytes storage data = _mutable[tokenId];
        for (uint256 i = 0; i < 32; i++) {
            ipfsCid[i] = data[i + 1]; // skip 1 byte, version number
        }
        return
            string(
                abi.encodePacked(
                    "ipfs://",
                    Utility.toBase58(
                        abi.encodePacked(uint8(0x12), uint8(0x20), ipfsCid)
                    )
                )
            );
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

    function upload(
        bytes32 ipfsMetadata,
        bytes memory scriptBytes,
        bytes memory environment,
        uint160[] memory references,
        uint256 includeCost
    ) public {
        // mint a new token and upload it
        // but make scripts unique by hashing them
        uint160 hash =
            uint160(
                uint256(keccak256(abi.encodePacked(scriptBytes, references)))
            );
        require(!_exists(hash), "HastenScript: script already minted");

        _mint(msg.sender, hash);

        _immutable[hash] = abi.encodePacked(
            immutableVersion,
            msg.sender, // we want those persistent even on non archive nodes.. not depending on transaction data
            uint32(block.timestamp), // good until Sun Feb 07 2106 ...
            scriptBytes
        );

        if (environment.length > 0) {
            _mutable[hash] = abi.encodePacked(
                mutableVersion,
                ipfsMetadata,
                environment
            );
        } else {
            _mutable[hash] = abi.encodePacked(mutableVersion, ipfsMetadata);
        }

        if (references.length > 0) {
            _references[hash] = references;
            if (address(_daoToken) != address(0)) {
                // We need to ensure that _daoToken is always populated after beign launched or we break incentives
                uint256 balance = _daoToken.balanceOf(msg.sender);
                for (uint256 i = 0; i < references.length; i++) {
                    uint256 cost = includeCostOf(references[i]);
                    if (cost > 0) {
                        require(
                            balance >= cost,
                            "HastenScript: not enough balance to reference script"
                        );
                        address owner = ownerOf(references[i]);
                        _daoToken.safeTransferFrom(msg.sender, owner, cost);
                        balance -= cost;
                    }
                }
            }
        }

        _includeCost[hash] = includeCost;
    }

    function update(
        uint160 scriptHash,
        bytes32 ipfsMetadata,
        bytes memory environment,
        uint256 includeCost
    ) public {
        require(
            _exists(scriptHash) && msg.sender == ownerOf(scriptHash),
            "HastenScript: Only the owner of the script can update it"
        );

        _mutable[scriptHash] = abi.encodePacked(
            mutableVersion,
            ipfsMetadata,
            environment
        );

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
                _daoToken.safeIncreaseAllowance(address(this), _reward);
                _daoToken.safeTransferFrom(address(this), msg.sender, _reward);
                _rewardBlocks[msg.sender] = block.number;
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
