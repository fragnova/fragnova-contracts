pragma solidity ^0.7.4;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";
import "./IHastenScript.sol";

contract HastenMod is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 internal constant OwnerReward = 1;

    // mapping for scripts storage
    mapping(uint256 => uint256) private _scripts;
    mapping(uint256 => bytes) private _environments;
    mapping(uint256 => uint256) private _rewardBlocks;

    IHastenScript internal immutable _scriptsLibrary;
    IERC20 internal immutable _daoToken;

    constructor(address libraryAddress, address daoAddress)
        ERC721("Hasten Mod NFT", "HSTN")
    {
        _scriptsLibrary = IHastenScript(libraryAddress);
        _daoToken = IERC20(daoAddress);
    }

    function script(uint256 modId)
        public
        view
        returns (bytes memory scriptBytes, bytes memory environment)
    {
        require(
            _exists(modId),
            "HastenScript: script query for nonexistent token"
        );

        (bytes memory byteCode, ) = _scriptsLibrary.script(_scripts[modId]);

        return (byteCode, _environments[modId]);
    }

    function upload(
        string memory tokenURI,
        uint256 scriptHash,
        bytes memory environment
    ) public {
        require(
            msg.sender == _scriptsLibrary.ownerOf(scriptHash),
            "Only the owner of the script can upload mods"
        );

        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _scripts[newItemId] = scriptHash;
        _environments[newItemId] = environment;
        _setTokenURI(newItemId, tokenURI);
    }

    function update(uint256 modId, bytes memory environment) public {
        require(
            msg.sender == ownerOf(modId),
            "Only the owner of the mod can update its environment"
        );

        _environments[modId] = environment;
    }

    // reward the owner of the Script
    // limited to once per block for safety reasons
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        // ensure not a mint or burn
        if (
            to != address(0) &&
            from != address(0) &&
            _rewardBlocks[tokenId] != block.number &&
            _daoToken.balanceOf(address(this)) > OwnerReward
        ) {
            address scriptOwner = _scriptsLibrary.ownerOf(_scripts[tokenId]);
            _daoToken.transferFrom(address(this), scriptOwner, OwnerReward);
            _rewardBlocks[tokenId] = block.number;
        }
    }
}
