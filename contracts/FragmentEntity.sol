pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IFragmentTemplate.sol";
import "./Utility.sol";
import "./Ownable.sol";

contract FragmentEntity is ERC721, Ownable, Initializable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    uint8 private constant dataVersion = 0x1;

    Counters.Counter private _tokenIds;

    // mapping for templates storage
    mapping(uint256 => bytes32) private _metadataURIs;
    mapping(uint256 => uint160) private _entityRefs;

    IFragmentTemplate private _templatesLibrary;
    address private _delegate;
    uint256 private _publicMintingPrice;
    uint160 private _templateId;
    uint32 private _maxPublicAmount;
    uint32 private _publicCap;
    bool private _publicMinting;

    // upload event with data
    event Upload(
        uint256 indexed first,
        uint256 last,
        uint8 version,
        bytes environment
    );

    // royalties event
    event Earned(uint256 total, uint256 royalties, uint256 vault);

    uint256 private _totalOwnedEarned;
    uint256 private _totalVaultEarned;

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
        uint160 dataHash =
            uint160(
                uint256(keccak256(abi.encodePacked(_templateId, environment)))
            );

        uint256 first = _tokenIds.current() + 1;

        for (uint256 i = 0; i < amount; i++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();

            _mint(msg.sender, newItemId);

            _entityRefs[newItemId] = dataHash;
            _metadataURIs[newItemId] = ipfsMetadata;
        }

        uint256 last = _tokenIds.current();

        emit Upload(first, last, dataVersion, environment);
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

        // pay royalties
        // for now just send 5% to vault
        // we should also sort out references royalties
        uint256 royalties = price - ((price / 100) * 5);
        uint256 toOwner = price - royalties;
        payable(owner()).transfer(toOwner);
        _templatesLibrary.getVault().transfer(royalties);
        emit Earned(price, 0, royalties);

        _totalOwnedEarned += toOwner;
        _totalVaultEarned += royalties;

        // mint it
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

    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        public
        onlyOwner
    {
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
    }

    function recoverETH(uint256 amount) public onlyOwner {
        payable(owner()).transfer(amount);
    }
}
