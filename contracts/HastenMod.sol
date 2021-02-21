pragma solidity ^0.7.4;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "./HastenScript.sol";
import "./HastenDAOToken.sol";

contract HastenMod is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 internal OwnerReward = 1 * (10**16);
    uint256 internal constant UIntMax = uint256(-1);

    // mapping for scripts storage
    mapping(uint256 => uint256) private _scripts;
    mapping(uint256 => bytes) private _environments;
    mapping(uint256 => address) private _signers;
    mapping(address => uint256) private _rewardBlocks;

    HastenScript internal immutable _scriptsLibrary;
    HastenDAOToken internal immutable _daoToken;

    constructor(address libraryAddress, address daoAddress)
        ERC721("Hasten Mod NFT", "HSTNmV0")
    {
        _scriptsLibrary = HastenScript(libraryAddress);
        _daoToken = HastenDAOToken(daoAddress);
    }

    function script(uint256 modId)
        public
        view
        returns (
            bytes memory scriptBytes,
            bytes memory environment,
            uint256 scriptHash
        )
    {
        require(
            _exists(modId),
            "HastenScript: script query for nonexistent token"
        );

        (bytes memory byteCode, , uint256 hash) =
            _scriptsLibrary.scriptFromId(_scripts[modId]);

        return (byteCode, _environments[modId], hash);
    }

    function setDelegate(uint256 scriptId, address delegate) public {
        require(
            msg.sender == _scriptsLibrary.ownerOf(scriptId),
            "HastenMod: Only the owner of the script can set signer delegate"
        );

        _signers[scriptId] = delegate;
    }

    function _upload(
        string memory tokenURI,
        uint256 scriptId,
        bytes memory environment
    ) internal {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _scripts[newItemId] = scriptId;
        _environments[newItemId] = environment;
        _setTokenURI(newItemId, tokenURI);
    }

    function upload(
        string memory tokenURI,
        uint256 scriptId,
        bytes memory environment
    ) public {
        require(
            msg.sender == _scriptsLibrary.ownerOf(scriptId),
            "HastenMod: Only the owner of the script can upload mods"
        );

        _upload(tokenURI, scriptId, environment);
    }

    /*
        This is to allow any user to upload something as long as the owner of the script authorizes.
    */
    function uploadWithDelegateAuth(
        bytes memory signature,
        string memory tokenURI,
        uint256 scriptId,
        bytes memory environment
    ) public {
        bytes32 hash =
            ECDSA.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        msg.sender,
                        tokenURI,
                        scriptId,
                        environment
                    )
                )
            );
        require(
            _signers[scriptId] == ECDSA.recover(hash, signature),
            "HastenMod: Invalid signature"
        );

        _upload(tokenURI, scriptId, environment);
    }

    // reward the owner of the Script
    // limited to once per block for safety reasons
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        // ensure not a mint or burn
        if (to != address(0) && from != address(0)) {
            address scriptOwner = _scriptsLibrary.ownerOf(_scripts[tokenId]);
            if (
                _rewardBlocks[scriptOwner] != block.number &&
                _daoToken.balanceOf(address(this)) > OwnerReward
            ) {
                _daoToken.increaseAllowance(address(this), OwnerReward);
                _daoToken.transferFrom(address(this), scriptOwner, OwnerReward);
                _rewardBlocks[scriptOwner] = block.number;
            }
        }
    }

    function setScriptOwnerReward(uint256 amount) public onlyOwner {
        OwnerReward = amount;
    }

    function getScriptOwnerReward() public view returns (uint256) {
        return OwnerReward;
    }
}
