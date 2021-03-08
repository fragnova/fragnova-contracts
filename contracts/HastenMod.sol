pragma solidity ^0.7.4;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";
import "openzeppelin-solidity/contracts/cryptography/ECDSA.sol";
import "./HastenScript.sol";
import "./HastenDAOToken.sol";
import "./Ownable.sol";

contract HastenMod is ERC721, Ownable {
    // reserved by proxy
    address internal _impl = address(0);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 internal _ownerReward = 1 * (10**16);

    // mapping for scripts storage
    mapping(uint256 => uint160) private _scripts;
    mapping(uint256 => bytes) private _environments;
    mapping(uint256 => address) private _signers;
    mapping(address => uint256) private _rewardBlocks;

    HastenScript internal immutable _scriptsLibrary;
    HastenDAOToken internal _daoToken;

    constructor(address libraryAddress, address daoAddress)
        ERC721("Hasten Mod NFT v0", "MOD")
        Ownable(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974))
    {
        _scriptsLibrary = HastenScript(libraryAddress);
        _daoToken = HastenDAOToken(daoAddress);
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

    function setDelegate(uint256 scriptId, address delegate) public {
        require(
            msg.sender == _scriptsLibrary.ownerOf(scriptId),
            "HastenMod: Only the owner of the script can set signer delegate"
        );

        _signers[scriptId] = delegate;
    }

    function _upload(
        string memory tokenURI,
        uint160 scriptId,
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
        uint160 scriptId,
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
        uint160 scriptId,
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
        if (
            to != address(0) &&
            from != address(0) &&
            address(_daoToken) != address(0)
        ) {
            address scriptOwner = _scriptsLibrary.ownerOf(_scripts[tokenId]);
            if (
                _rewardBlocks[scriptOwner] != block.number &&
                _daoToken.balanceOf(address(this)) > _ownerReward
            ) {
                _daoToken.increaseAllowance(address(this), _ownerReward);
                _daoToken.transferFrom(
                    address(this),
                    scriptOwner,
                    _ownerReward
                );
                _rewardBlocks[scriptOwner] = block.number;
            }
        }
    }

    function setScriptOwnerReward(uint256 amount) public onlyOwner {
        _ownerReward = amount;
    }

    function getScriptOwnerReward() public view returns (uint256) {
        return _ownerReward;
    }

    function setDAOToken(address addr) public onlyOwner {
        _daoToken = HastenDAOToken(addr);
    }

    function getDAOToken() public view returns (address) {
        return address(_daoToken);
    }
}
