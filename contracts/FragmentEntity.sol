pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "./FragmentTemplate.sol";
import "./FragmentVault.sol";
import "./Utility.sol";
import "./FragmentNFT.sol";

struct FragmentInitData {
    uint160 templateId;
    address templatesLibrary;
    address payable vault;
    bool unique;
    uint32 maxSupply;
}

contract FragmentEntity is FragmentNFT, Initializable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    uint8 private constant _dataVersion = 0x1;

    // royalties distribution table
    uint256 private constant _p1 = 8000; // percentage with 2 decimals added = 80% - Creator
    uint256 private constant _p2 = 2000; // percentage with 2 decimals added = 20% - Vault

    Counters.Counter private _tokenIds;

    // mapping for templates storage
    mapping(uint256 => bytes32) private _metadataURIs;
    mapping(uint256 => uint160) private _entityRefs;
    mapping(uint256 => uint256) private _envToId;

    FragmentTemplate private _templatesLibrary;
    FragmentVault private _vault;
    address private _delegate;
    uint256 private _publicMintingPrice;
    uint256 private _dutchStartBlock;
    uint256 private _dutchStep;
    uint160 private _templateId;
    uint32 private _maxSupply;
    uint32 private _maxPublicAmount;
    uint32 private _publicCap;
    uint8 private _publicMinting; // 0 no, 1 normal, 2 dutch auction
    bool private _uniqueEnv;

    uint8 private constant NO_PUB_MINTING = 0;
    uint8 private constant PUB_MINTING = 1;
    uint8 private constant DUTCH_MINTING = 2;

    // upload event with data
    event Upload(
        uint256 indexed first,
        uint256 last,
        uint8 version,
        bytes environment
    );

    // royalties event
    event Earned(uint256 total, uint256 royalties, uint256 vault);

    constructor() ERC721("Entity", "FRAGe") Ownable(address(0)) {
        // this is just for testing - deployment has no constructor args (literally comment out)
        // Master template to entity
        _templateId = 0;
        // ERC721 - this we must make sure happens only and ever in the beginning
        // Of course being proxied it might be overwritten but if ownership is finally burned it's going to be fine!
        _templatesLibrary = FragmentTemplate(address(0));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == _INTERFACE_ID_FEES ||
            super.supportsInterface(interfaceId);
    }

    function bootstrap(
        string calldata tokenName,
        string calldata tokenSymbol,
        FragmentInitData calldata params
    ) public initializer {
        _templatesLibrary = FragmentTemplate(params.templatesLibrary);

        address towner = _templatesLibrary.ownerOf(params.templateId);

        // Ownable
        Ownable._bootstrap(towner);

        // Master template to entity
        _templateId = params.templateId;

        // Vault
        _vault = FragmentVault(params.vault);

        // ERC721 - this we must make sure happens only and ever in the beginning
        // Of course being proxied it might be overwritten but if ownership is finally burned it's going to be fine!
        _name = tokenName;
        _symbol = tokenSymbol;

        // Others
        _uniqueEnv = params.unique;
        _maxSupply = params.maxSupply;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "URI query for nonexistent token");

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
                    ),
                    "/metadata.json"
                )
            );
    }

    function getTemplate() public view returns (uint160) {
        return _templateId;
    }

    function getLibrary() public view returns (address) {
        return address(_templatesLibrary);
    }

    function setDelegate(address delegate) public onlyOwner {
        _delegate = delegate;
    }

    function _upload(
        bytes32 ipfsMetadata,
        bytes calldata environment,
        uint32 amount
    ) internal {
        uint160 dataHash = uint160(
            uint256(keccak256(abi.encodePacked(_templateId, environment)))
        );

        uint256 first = _tokenIds.current() + 1;

        for (uint256 i = 0; i < amount; i++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();
            require(
                _tokenIds.current() < _maxSupply,
                "Max minting limit has been reached"
            );

            require(
                !_uniqueEnv || _envToId[dataHash] == 0,
                "Unique token already minted."
            );
            _envToId[dataHash] = newItemId;

            _mint(msg.sender, newItemId);

            _entityRefs[newItemId] = dataHash;
            _metadataURIs[newItemId] = ipfsMetadata;
        }

        uint256 last = _tokenIds.current();

        emit Upload(first, last, _dataVersion, environment);
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
        // Sanity checks
        require(_publicMinting == PUB_MINTING, "Public minting not allowed");

        require(
            _tokenIds.current() + (amount - 1) < _publicCap,
            "Public minting limit has been reached"
        );

        require(amount <= _maxPublicAmount, "Invalid amount");

        uint256 price = amount * _publicMintingPrice;
        require(msg.value >= price, "Not enough value");

        // All good authenticate now
        bytes32 hash = ECDSA.toEthSignedMessageHash(
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
            "Invalid signature"
        );

        // pay royalties
        uint256 remaining = msg.value;

        // Creator/Author royalties
        {
            uint256 royalties = (price * _p1) / 10000;
            payable(owner()).transfer(royalties);
            remaining -= royalties;
            emit Earned(price, 0, royalties);
        }

        // Send the rest to the vault for distribution
        payable(address(_vault)).transfer(remaining);

        // mint it
        _upload(ipfsMetadata, environment, amount);
    }

    /*
        This is to allow public auction sales.
        We use a signature to allow an entity off chain to verify that the content is valid and vouch for it.
        If we want to skip that crafted address and random signatures can be used
    */
    function bid(
        bytes calldata signature,
        bytes32 ipfsMetadata,
        bytes calldata environment
    ) public payable {
        // Sanity checks
        require(_publicMinting == DUTCH_MINTING, "Auction bidding not allowed");

        require(
            _tokenIds.current() < _publicCap,
            "Minting limit has been reached"
        );

        // reduce price over time via blocks
        uint256 blocksDiff = block.number - _dutchStartBlock;
        uint256 price = _publicMintingPrice - (_dutchStep * blocksDiff);
        require(msg.value >= price, "Not enough value");

        // Authenticate
        bytes32 hash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    Utility.getChainId(),
                    _templateId,
                    ipfsMetadata,
                    environment
                )
            )
        );
        require(
            _delegate != address(0x0) &&
                _delegate == ECDSA.recover(hash, signature),
            "Invalid signature"
        );

        // pay royalties
        uint256 remaining = msg.value;

        // Creator/Author royalties
        {
            uint256 royalties = (price * _p1) / 10000;
            payable(owner()).transfer(royalties);
            remaining -= royalties;
            emit Earned(price, 0, royalties);
        }

        // Send the rest to the vault for distribution
        payable(address(_vault)).transfer(remaining);

        // mint it
        _upload(ipfsMetadata, environment, 1);
    }

    function currentBidPrice() public view returns (uint256) {
        assert(_publicMinting == DUTCH_MINTING);
        // reduce price over time via blocks
        uint256 blocksDiff = block.number - _dutchStartBlock;
        uint256 price = _publicMintingPrice - (_dutchStep * blocksDiff);
        return price;
    }

    function isMarketOpen() public view returns (bool) {
        return
            _publicMinting != NO_PUB_MINTING &&
            _tokenIds.current() < _publicCap;
    }

    function setPublicSale(
        uint256 price,
        uint32 maxAmount,
        uint32 cap
    ) public onlyOwner {
        _publicMinting = PUB_MINTING;
        _publicMintingPrice = price;
        _maxPublicAmount = maxAmount;
        _publicCap = cap;
        assert(_publicCap <= _maxSupply);
    }

    function openDutchAuction(
        uint256 maxPrice,
        uint256 priceStep,
        uint32 slots
    ) public onlyOwner {
        _publicMinting = DUTCH_MINTING;
        _publicMintingPrice = maxPrice;
        _dutchStartBlock = block.number;
        _dutchStep = priceStep;
        _publicCap = slots;
        assert(_publicCap <= _maxSupply);
    }

    function stopMarket() public onlyOwner {
        _publicMinting = NO_PUB_MINTING;
    }

    /*
        Allow owners to update metadata
    */
    function updateMetadata(uint256 tokenId, bytes32 metadata) public {
        require(_exists(tokenId), "Nonexistent token");
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        _metadataURIs[tokenId] = metadata;
    }

    // This should add support for most popular secondary markets royalties on sales

    /*
     * bytes4(keccak256('getFeeBps(uint256)')) == 0x0ebd4c7f
     * bytes4(keccak256('getFeeRecipients(uint256)')) == 0xb9c4d9fb
     *
     * => 0x0ebd4c7f ^ 0xb9c4d9fb == 0xb7799584
     */
    bytes4 private constant _INTERFACE_ID_FEES = 0xb7799584;

    function getFeeRecipients(
        uint256 /*id*/
    ) public view returns (address payable[] memory split) {
        split = new address payable[](2);
        split[0] = payable(owner());
        split[1] = payable(address(_vault));
    }

    function getFeeBps(
        uint256 /*id*/
    ) public pure returns (uint256[] memory split) {
        split = new uint256[](2);
        split[0] = _p1 / 10;
        split[1] = _p2 / 10;
    }
}
