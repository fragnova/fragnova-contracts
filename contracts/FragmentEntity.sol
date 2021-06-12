pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";
import "./Flushable.sol";
import "./IFragmentTemplate.sol";
import "./Utility.sol";

contract FragmentEntity is ERC721, Flushable, Initializable {
    uint8 private constant dataVersion = 0x1;

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // mapping for templates storage
    mapping(uint256 => bytes) private _entityData;
    mapping(uint256 => bytes32) private _metadataURIs;
    mapping(uint256 => uint160) private _entityRefs;

    IFragmentTemplate internal _templatesLibrary;
    address internal _delegate;
    uint256 internal _publicMintingPrice;
    uint160 internal _templateId;
    uint32 internal _maxPublicAmount;
    uint32 internal _publicCap;
    bool internal _publicMinting;

    constructor() ERC721("Entity", "FRAGe") Ownable(address(0)) {
        // this is just for testing - deployment has no constructor args (literally comment out)
        // Master template to entity
        _templateId = 0;
        // ERC721 - this we must make sure happens only and ever in the beginning
        // Of course being proxied it might be overwritten but if ownership is finally burned it's going to be fine!
        _templatesLibrary = IFragmentTemplate(address(0));
    }

    function bootstrap(
        string calldata tokenName,
        string calldata tokenSymbol,
        uint160 templateId,
        address templatesLibrary
    ) public initializer {
        _templatesLibrary = IFragmentTemplate(templatesLibrary);

        address towner = _templatesLibrary.ownerOf(templateId);

        // Ownable
        Ownable._bootstrap(towner);

        // Master template to entity
        _templateId = templateId;

        // ERC721 - this we must make sure happens only and ever in the beginning
        // Of course being proxied it might be overwritten but if ownership is finally burned it's going to be fine!
        _name = tokenName;
        _symbol = tokenSymbol;
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

        return
            string(
                abi.encodePacked(
                    "ipfs://",
                    Utility.toBase58(
                        abi.encodePacked(
                            uint8(0x12),
                            uint8(0x20),
                            _metadataURIs[tokenId]
                        ),
                        46
                    )
                )
            );
    }

    function dataOf(uint256 entityId)
        public
        view
        returns (
            bytes memory immutableData,
            bytes memory mutableData,
            bytes memory entityData
        )
    {
        require(
            _exists(entityId),
            "FragmentTemplate: template query for nonexistent token"
        );

        entityData = _entityData[_entityRefs[entityId]];
        (immutableData, mutableData) = _templatesLibrary.dataOf(_templateId);
    }

    function setDelegate(address delegate) public onlyOwner {
        _delegate = delegate;
    }

    function _upload(
        bytes32 ipfsMetadata,
        bytes calldata environment,
        uint32 amount
    ) internal {
        uint160 dataHash =
            uint160(
                uint256(keccak256(abi.encodePacked(_templateId, environment)))
            );

        // store only if not already present
        if (_entityData[dataHash].length == 0) {
            _entityData[dataHash] = abi.encodePacked(dataVersion, environment);
        }

        for (uint256 i = 0; i < amount; i++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();

            _mint(msg.sender, newItemId);

            _entityRefs[newItemId] = dataHash;
            _metadataURIs[newItemId] = ipfsMetadata;
        }
    }

    function upload(
        bytes32 ipfsMetadata,
        bytes calldata environment,
        uint32 amount
    ) public onlyOwner {
        _upload(ipfsMetadata, environment, amount);
    }

    /*
        This is to allow public sales.
        We use a signature to allow an entity off chain to verify that the content is valid and vouch for it.
        If we want to skip that crafted address and random signatures can be used
    */
    function mint(
        bytes calldata signature,
        bytes32 ipfsMetadata,
        bytes calldata environment,
        uint32 amount
    ) public payable {
        bytes32 hash =
            ECDSA.toEthSignedMessageHash(
                keccak256(
                    abi.encodePacked(
                        msg.sender,
                        Utility.getChainId(),
                        _templateId,
                        ipfsMetadata,
                        environment,
                        amount
                    )
                )
            );
        require(
            _delegate != address(0x0) &&
                _delegate == ECDSA.recover(hash, signature),
            "FragmentEntity: Invalid signature"
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
        require(_exists(tokenId), "FragmentTemplate: nonexistent token");
        require(
            ownerOf(tokenId) == msg.sender,
            "FragmentTemplate: not token owner"
        );
        _metadataURIs[tokenId] = metadata;
    }
}
