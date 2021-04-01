pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "./HastenNFT.sol";
import "./IpfsMetadataV0.sol";
import "./ScriptStorageV0.sol";

// this contract uses proxy, let's keep any storage inside other modules
// this should make it easier to upgrade
contract HastenScript is
    HastenNFT,
    Initializable,
    IpfsMetadataV0,
    ScriptStorageV0
{
    using SafeERC20 for IERC20;

    constructor()
        ERC721("Hasten Script v0 NFT", "CODE")
        Ownable(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974))
    {
        // NOT INVOKED
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
        return getUrl(tokenId);
    }

    function script(uint160 scriptHash)
        public
        view
        returns (bytes memory scriptBytes, bytes memory environment)
    {
        return (_scripts[scriptHash], _environments[scriptHash]);
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

        _ipfsMetadataV0[hash] = ipfsMetadata;
        _scripts[hash] = scriptBytes;
        _environments[hash] = environment;
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

        _ipfsMetadataV0[scriptHash] = ipfsMetadata;
        _environments[scriptHash] = environment;
        emit EnvironmentUpdated(scriptHash);
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
                _daoToken.safeTransferFrom(
                    address(this),
                    msg.sender,
                    _reward
                );
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
