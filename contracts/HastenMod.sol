pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";
import "./Flushable.sol";
import "./HastenScript.sol";
import "./Utility.sol";

contract HastenMod is ERC721, Flushable, Initializable {
    uint8 private constant dataVersion = 0x1;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // mapping for scripts storage
    mapping(uint256 => bytes) private _modData;
    mapping(uint256 => bytes32) private _metadataURIs;
    mapping(uint256 => uint160) private _modRefs;

    HastenScript internal _scriptsLibrary;
    address internal _delegate;
    uint256 internal _publicMintingPrice;
    uint160 internal _scriptId;
    uint32 internal _maxPublicAmount;
    uint32 internal _publicCap;
    bool internal _publicMinting;

    // constructor() ERC721("Mod", "MOD") Ownable(address(0)) {
    //     bootstrap("Mod", "MOD", 0, address(0));
    //     _scriptsLibrary = HastenScript(address(0));
    // }

    constructor(
        address libraryAddress,
        uint160 scriptId,
        address owner
    ) ERC721("Mod", "MOD") Ownable(owner) {
        // this is just for testing - deployment has no constructor args (literally comment out)
        bootstrap("Mod", "MOD", scriptId, owner);
        _scriptsLibrary = HastenScript(libraryAddress);
    }

    function bootstrap(
        string memory name,
        string memory symbol,
        uint160 scriptId,
        address owner
    ) public payable initializer {
        // Ownable
        Ownable._bootstrap(owner);

        // Master script to mod
        _scriptId = scriptId;

        // ERC721 - this we must make sure happens only and ever in the beginning
        // Of course being proxied it might be overwritten but if ownership is finally burned it's going to be fine!
        _name = name;
        _symbol = symbol;

        _scriptsLibrary = HastenScript(
            0xC0DE00aa1328aF9263BA5bB5e3d17521AF58b32F
        ); // proxy script library
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

        return
            string(
                abi.encodePacked(
                    "ipfs://",
                    Utility.toBase58(
                        abi.encodePacked(
                            uint8(0x12),
                            uint8(0x20),
                            _metadataURIs[tokenId]
                        )
                    )
                )
            );
    }

    function dataOf(uint256 modId)
        public
        view
        returns (
            bytes memory immutableData,
            bytes memory mutableData,
            bytes memory modData
        )
    {
        require(
            _exists(modId),
            "HastenScript: script query for nonexistent token"
        );

        modData = _modData[_modRefs[modId]];
        (immutableData, mutableData) = _scriptsLibrary.dataOf(_scriptId);
    }

    function setDelegate(address delegate) public onlyOwner {
        _delegate = delegate;
    }

    function _upload(
        bytes32 ipfsMetadata,
        bytes memory environment,
        uint32 amount
    ) internal {
        uint160 dataHash =
            uint160(
                uint256(keccak256(abi.encodePacked(_scriptId, environment)))
            );

        // store only if not already present
        if (_modData[dataHash].length == 0) {
            _modData[dataHash] = abi.encodePacked(dataVersion, environment);
        }

        for (uint256 i = 0; i < amount; i++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();

            _mint(msg.sender, newItemId);

            _modRefs[newItemId] = dataHash;
            _metadataURIs[newItemId] = ipfsMetadata;
        }
    }

    function upload(
        bytes32 ipfsMetadata,
        bytes memory environment,
        uint32 amount
    ) public onlyOwner {
        _upload(ipfsMetadata, environment, amount);
    }

    /*
        This is to allow public sales.
        We use a signature to allow an entity off chain to verify that the content is valid and vouch for it.
        If we want to skip that crafted address and signatures can be used
    */
    function mint(
        bytes memory signature,
        bytes32 ipfsMetadata,
        bytes memory environment,
        uint32 amount
    ) public payable {
        bytes32 hash =
            ECDSA.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        msg.sender,
                        Utility.getChainId(),
                        _scriptId,
                        ipfsMetadata,
                        environment,
                        amount
                    )
                )
            );
        require(
            _delegate != address(0x0) &&
                _delegate == ECDSA.recover(hash, signature),
            "HastenMod: Invalid signature"
        );

        require(_publicMinting, "Public minting not allowed");

        require(
            _tokenIds.current() < _publicCap,
            "Public minting limit has been reached"
        );

        require(amount <= _maxPublicAmount, "Invalid amount");

        uint256 price = amount * _publicMintingPrice;
        require(msg.value >= price, "Not enough value");

        _upload(ipfsMetadata, environment, amount);
    }

    function setPublicSale(
        bool enabled,
        uint256 price,
        uint32 maxAmount,
        uint32 cap
    ) public onlyOwner {
        _publicMinting = enabled;
        _publicMintingPrice = price;
        _maxPublicAmount = maxAmount;
        _publicCap = cap;
    }

    /*
        Allow owners to update metadata
    */
    function updateMetadata(uint256 tokenId, bytes32 metadata) public {
        require(_exists(tokenId), "HastenScript: nonexistent token");
        require(
            ownerOf(tokenId) == msg.sender,
            "HastenScript: not token owner"
        );
        _metadataURIs[tokenId] = metadata;
    }
}
