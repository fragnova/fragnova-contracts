pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/utils/Counters.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";
import "./HastenNFT.sol";
import "./HastenScript.sol";
import "./Utility.sol";

contract HastenMod is HastenNFT {
    uint8 private constant mutableVersion = 0x1;

    using SafeERC20 for IERC20;

    mapping(uint256 => address) private _signers;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // mapping for scripts storage
    mapping(uint256 => uint160) private _scripts;
    mapping(uint256 => bytes) private _mutable;

    HastenScript internal immutable _scriptsLibrary;

    constructor(address libraryAddress, address daoAddress)
        ERC721("Hasten Mod v0 NFT ", "MOD")
        Ownable(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974))
    {
        _scriptsLibrary = HastenScript(libraryAddress);
        _daoToken = IERC20(daoAddress);
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

    function dataOf(uint256 modId)
        public
        view
        returns (bytes memory immutableData, bytes memory mutableData)
    {
        require(
            _exists(modId),
            "HastenScript: script query for nonexistent token"
        );
        (bytes memory byteCode, ) = _scriptsLibrary.dataOf(_scripts[modId]);
        return (byteCode, _mutable[modId]);
    }

    function setDelegate(uint256 scriptId, address delegate) public {
        require(
            msg.sender == _scriptsLibrary.ownerOf(scriptId),
            "HastenMod: Only the owner of the script can set signer delegate"
        );

        _signers[scriptId] = delegate;
    }

    function _upload(
        bytes32 ipfsMetadata,
        uint160 scriptId,
        bytes memory environment
    ) internal {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        _mint(msg.sender, newItemId);

        _scripts[newItemId] = scriptId;
        _mutable[newItemId] = abi.encodePacked(
            mutableVersion,
            ipfsMetadata,
            environment
        );
    }

    function upload(
        bytes32 ipfsMetadata,
        uint160 scriptId,
        bytes memory environment
    ) public {
        require(
            msg.sender == _scriptsLibrary.ownerOf(scriptId),
            "HastenMod: Only the owner of the script can upload mods"
        );

        _upload(ipfsMetadata, scriptId, environment);
    }

    /*
        This is to allow any user to upload something as long as the owner of the script authorizes.
    */
    function uploadWithDelegateAuth(
        bytes memory signature,
        bytes32 ipfsMetadata,
        uint160 scriptId,
        bytes memory environment
    ) public {
        bytes32 hash =
            ECDSA.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        msg.sender,
                        Utility.getChainId(),
                        ipfsMetadata,
                        scriptId,
                        environment
                    )
                )
            );
        require(
            _signers[scriptId] != address(0x0) &&
                _signers[scriptId] == ECDSA.recover(hash, signature),
            "HastenMod: Invalid signature"
        );

        _upload(ipfsMetadata, scriptId, environment);
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
                _daoToken.balanceOf(address(this)) > _reward
            ) {
                _daoToken.safeIncreaseAllowance(address(this), _reward);
                _daoToken.safeTransferFrom(address(this), scriptOwner, _reward);
                _rewardBlocks[scriptOwner] = block.number;
            }
        } else if (to == address(0)) {
            // burn, cleanup storage, it's the end
            _scripts[tokenId] = 0x0;
            _mutable[tokenId] = new bytes(0);
        }
    }

    function setScriptOwnerReward(uint256 amount) public onlyOwner {
        _reward = amount;
    }

    function getScriptOwnerReward() public view returns (uint256) {
        return _reward;
    }
}
