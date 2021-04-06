pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "./HastenNFT.sol";
import "./ScriptStorage.sol";

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
        // NOT INVOKED IF PROXY
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

        return getUrl(tokenId, 1);
    }

    function dataOf(uint160 scriptHash)
        public
        view
        returns (bytes memory immutableData, bytes memory mutableData)
    {
        return (_immutable[scriptHash], _mutable[scriptHash]);
    }

    function upload(
        bytes32 ipfsMetadata,
        bytes memory scriptBytes,
        bytes memory environment
    ) public {
        // mint a new token and upload it
        // but make scripts unique by hashing them
        uint160 hash = uint160(uint256(keccak256(scriptBytes)));
        require(!_exists(hash), "HastenScript: script already minted");

        _mint(msg.sender, hash);

        _immutable[hash] = abi.encodePacked(
            immutableVersion,
            msg.sender,
            uint32(block.timestamp), // good until Sun Feb 07 2106 ...
            scriptBytes
        );
        _mutable[hash] = abi.encodePacked(
            mutableVersion,
            ipfsMetadata,
            environment
        );
    }

    function update(
        uint160 scriptHash,
        bytes32 ipfsMetadata,
        bytes memory environment
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
