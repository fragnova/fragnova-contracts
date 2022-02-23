/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-solidity/contracts/utils/Counters.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "./IFragment.sol";
import "./IVault.sol";
import "./IUtility.sol";
import "./RoyaltiesReceiver.sol";

struct FragmentInitData {
    // The Proto-Fragment ID
    uint256 fragmentId;
    uint256 maxSupply;
    // The address of the `Fragment` Contract
    address fragmentsLibrary;
    // The address of RezProxy Contract that delegates all its calls to a Vault Contract
    address payable vault;
    bool unique;
    /// If `updatable` is false, the Fragment cannot be updated
    bool updateable;
}

struct EntityData {
    uint64 blockNum;
}


/// @title An Entity/Fragment Contract. This Contract stores one and only one Entity/Fragment.
/// @dev This contract is an ERC-721 Initializable Contract
contract Entity is ERC721Enumerable, Initializable, RoyaltiesReceiver {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;

    uint8 private constant _dataVersion = 0x1;

    Counters.Counter private _tokenIds;

    // mapping for fragments storage
    // Maps a Fragment ID to an EntityData Struct
    mapping(uint256 => EntityData) private _idToBlock;
    // Maps a Fragment ID to a Data Hash
    mapping(uint256 => bytes32) private _entityRefs;
    // Maps a Data Hash To a Set of Fragment IDs
    mapping(uint256 => EnumerableSet.UintSet) private _envToId;

    IFragment private _fragmentsLibrary;
    IVault private _vault;
    address private _delegate;
    uint256 private _publicMintingPrice;
    uint256 private _dutchStartBlock;
    uint256 private _dutchStep;
    // The ID of the Proto-Fragment that is linked with this Contract
    uint256 private _fragmentId;
    uint256 private _maxSupply;
    uint256 private _maxPublicAmount;
    uint256 private _publicCap;
    uint8 private _publicMinting; // 0 no, 1 normal, 2 dutch auction
    // ¿All Fragment Tokens must have a unique `environment`?
    bool private _uniqueEnv;
    // If this is false, the Fragment/Entity assosciated with this Entity Contract cannot be updated
    bool private _canUpdate;

    uint8 private constant NO_PUB_MINTING = 0;
    uint8 private constant PUB_MINTING = 1;
    uint8 private constant DUTCH_MINTING = 2;

    string private _metaname;
    string private _desc;
    string private _url;

    event Updated(uint256 indexed id);

    constructor() ERC721("Entity", "FRAGe") {
        // this is just for testing - deployment has no constructor args (literally comment out)
        // Master fragment to entity
        _fragmentId = 0;
        // ERC721 - this we must make sure happens only and ever in the beginning
        // Of course being proxied it might be overwritten but if ownership is finally burned it's going to be fine!
        _fragmentsLibrary = IFragment(address(0));

        setupRoyalties(payable(0), FRAGMENT_ROYALTIES_BPS);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            _supportsInterface(interfaceId) ||
            super.supportsInterface(interfaceId);
    }

    // Use owner() as interface, but in this case it's just the controller NOT THE OWNER
    // this is useful only wrt OpenSea so far and other centralized exchanges
    // tl;dr until OpenSea becomes open to adopt EIP2981 we need to use owner() this way.
    function owner() public view returns (address) {
        IUtility ut = IUtility(_fragmentsLibrary.getUtilityLibrary());
        if (ut.overrideOwner()) {
            return _fragmentsLibrary.getController();
        } else {
            return fragmentOwner();
        }
    }

    /// @notice Returns the address of the owner of this Fragment/Entity
    function fragmentOwner() public view returns (address) {
        return _fragmentsLibrary.ownerOf(_fragmentId);
    }

    modifier onlyOwner() {
        require(fragmentOwner() == msg.sender, "Caller is not the owner");
        _;
    }


    /// @notice The de-facto Constructor of the Entity Smart Contract
    /// @param tokenName - The name of the ERC-721 Token of this ERC-721 Contract
    /// @param tokenSymbol - The symbol of the ERC-721 Token of this ERC-721 Contract
    /// @param params - A Fragment. The fragment represented using the struct `FragmentInitData`
    /// @dev The `initializer` modifier ensures this function is only called once
    function bootstrap(
        string calldata tokenName,
        string calldata tokenSymbol,
        FragmentInitData calldata params
    ) external initializer {
        _fragmentsLibrary = IFragment(params.fragmentsLibrary);

        // Master fragment to entity
        _fragmentId = params.fragmentId;

        // Vault
        _vault = IVault(params.vault);

        // ERC721 - this we must make sure happens only and ever in the beginning
        // Of course being proxied it might be overwritten but if ownership is finally burned it's going to be fine!
        _name = tokenName;
        _symbol = tokenSymbol;

        // Others
        _uniqueEnv = params.unique;
        _maxSupply = params.maxSupply;
        _canUpdate = params.updateable;

        setupRoyalties(payable(address(_vault)), FRAGMENT_ROYALTIES_BPS);
    }

    /// @notice Returns the tokenURI of the ERC-721 Token with ID `tokenId`. (Note: Every ERC-721 Contract must have this function)
    /// The tokenURI on an NFT is a unique identifier of what the token "looks" like. A URI could be an API call over HTTPS, an IPFS hash, or anything else unique. (https://www.freecodecamp.org/news/how-to-make-an-nft-and-render-on-opensea-marketplace/#:~:text=come%20into%20play.-,TokenURI,hash%2C%20or%20anything%20else%20unique.)
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "URI query for nonexistent token");

        IUtility ut = IUtility(_fragmentsLibrary.getUtilityLibrary());

        return
            ut.buildEntityMetadata(
                tokenId,
                _entityRefs[tokenId],
                address(this),
                uint256(_idToBlock[tokenId].blockNum)
            );
    }

    /// @notice Returns a JSON that represents the storefront-level metadata (for example a Collection in OpenSea) for your contract
    function contractURI() public view returns (string memory) {
        IUtility ut = IUtility(_fragmentsLibrary.getUtilityLibrary());
        return
            ut.buildEntityRootMetadata(
                _metaname,
                _desc,
                _url,
                address(_vault),
                FRAGMENT_ROYALTIES_BPS
            );
    }

    /// @notice Set the Contract Information
    /// @param contractName - The contract name
    /// @param desc - The contract description
    /// @param url - The contract URL
    function setContractInfo(
        string calldata contractName,
        string calldata desc,
        string calldata url
    ) public onlyOwner {
        _metaname = contractName;
        _desc = desc;
        _url = url;
    }

    /// @notice Returns the Fragment ID of the Entity Contract
    function getFragment() external view returns (uint256) {
        return _fragmentId;
    }

    /// @notice Returns he address of the `Fragment` Contract
    function getLibrary() external view returns (address) {
        return address(_fragmentsLibrary);
    }

    /// @notice Get the address of the Assosciated Vault Smart Contract
    function getVault() external view returns (address) {
        return address(_vault);
    }

    /// @notice Given a token with ID `tokenID`, return the data hash of the token and the Block Number where the Token Data was last modified
    function getData(uint256 tokenId)
        external
        view
        returns (bytes32 environmentHash, uint256 blockNumber)
    {
        return (_entityRefs[tokenId], _idToBlock[tokenId].blockNum);
    }

    /// @notice Check if the Data Hash `dataHash` corresponds with the Token with id `id`
    function containsId(uint160 dataHash, uint256 id)
        external
        view
        returns (bool)
    {
        return _envToId[dataHash].contains(id);
    }

    /// @notice Set the state variable `_delegate`. `_delegate` is in charge of authenticating sigatures on this contract
    function setDelegate(address delegate) public onlyOwner {
        _delegate = delegate;
    }

    /// @notice to update the Fragment with id `id` (only the wwner of the Fragment can call this function)
    /// @dev Note: The Fragment must have been created with `updateable` set to true - otherwise the update is not allowed
    /// @param signature - A signature from the the state variable `_delegate`
    /// @param id - ¿The ID of the Fragment?
    /// @param environment - ¿The New Data of the Fragment?
    function update(
        bytes calldata signature,
        uint256 id,
        bytes calldata environment
    ) external {
        require(_canUpdate, "Update not allowed");
        require(ownerOf(id) == msg.sender, "Only owner can update");

        // All good authenticate now
        bytes32 hash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(
                    msg.sender,
                    _getChainId(),
                    _fragmentId,
                    environment
                )
            )
        );
        require(
            _delegate != address(0x0) &&
                _delegate == ECDSA.recover(hash, signature),
            "Invalid signature"
        );

        bytes32 dataHash = keccak256(
            abi.encodePacked(_fragmentId, environment)
        );


        _envToId[uint256(dataHash)].add(id);

        _entityRefs[id] = dataHash;
        _idToBlock[id] = EntityData(uint64(block.number));

        emit Updated(id);
    }

    /// @notice Uploads `amount` number of Fragment Tokens into this Contract, all of which have the data hash of `dataHash`. The owner of all these Fragment Tokens is `msg.sender`
    function _upload(bytes32 dataHash, uint96 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            _tokenIds.increment();
            uint256 newItemId = _tokenIds.current();
            require(
                _tokenIds.current() < _maxSupply,
                "Max minting limit has been reached"
            );

            // Ensure either `_uniqueEnv` is false or `_envToId[uint256(dataHash)]` does not exist
            require(
                !_uniqueEnv || _envToId[uint256(dataHash)].length() == 0,
                "Unique token already minted."
            );

            _envToId[uint256(dataHash)].add(newItemId);

            _mint(msg.sender, newItemId);

            _entityRefs[newItemId] = dataHash;
            _idToBlock[newItemId] = EntityData(uint64(block.number));
        }
    }

    /// Adds `amount` Fragments to this Contract. NOTE: ONLY THE OWNER OF THIS CONTRACT CAN CALL THIS FUNCTION
    /// @param environment - ¿
    /// @param amount - The amount of Fragments to add to this contract
    function upload(bytes calldata environment, uint96 amount)
        external
        onlyOwner
    {
        bytes32 dataHash = keccak256(
            abi.encodePacked(_fragmentId, environment)
        );

        _upload(dataHash, amount);
    }

    function _getChainId() private view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /*
        This is to allow public sales.
        We use a signature to allow an entity off chain to verify that the content is valid and vouch for it.
        If we want to skip that crafted address and random signatures can be used
    */
    /// @notice Allows the `msg.sender` to mint `amount` number of Fragment Tokens (which all have the same `environment`)
    /// @param `signature` - The signature provided by the `_delegate` state variable. The signature authenticates whether the the caller can mint/purchase these Fragment Tokens
    /// @param `environment` - ¿
    /// @param `amount` - The amount of Fragments the caller wants to purchase.
    /// @dev The caller can only mint if the `_publicCap` is greater than `_tokenIds.current() + (amount - 1)`
    ///      The caller can only mint a maximum of `_maxPublicAmount` tokens
    ///      The price of each Token is `_publicMintingPrice`
    ///
    function mint(
        bytes calldata signature,
        bytes calldata environment,
        uint96 amount
    ) external payable {
        // Sanity checks
        require(_publicMinting == PUB_MINTING, "Public minting not allowed");

        require(
            _tokenIds.current() + (amount - 1) < _publicCap,
            "Public minting limit has been reached"
        );

        require(amount <= _maxPublicAmount && amount > 0, "Invalid amount");

        uint256 price = amount * _publicMintingPrice;
        require(msg.value >= price, "Not enough value");

        bytes32 dataHash = keccak256(
            abi.encodePacked(_fragmentId, environment)
        );

        // All good authenticate now
        bytes32 hash = ECDSA.toEthSignedMessageHash(
            keccak256(
                abi.encodePacked(msg.sender, _getChainId(), dataHash, amount)
            )
        );
        require(
            _delegate != address(0x0) &&
                _delegate == ECDSA.recover(hash, signature),
            "Invalid signature"
        );

        // pay royalties
        _vault.deposit{value: msg.value}();

        // mint it
        _upload(dataHash, amount);
    }

    /*
        This is to allow public auction sales.
        We use a signature to allow an entity off chain to verify that the content is valid and vouch for it.
        If we want to skip that crafted address and random signatures can be used
    */
    /// @notice Allows the caller to bid for a Fragment (Note: The Auction Type is a Dutch Action. Therefore, the price of the Fragment will drop after every time-step/block)
    /// @param `signature` - The signature provided by the `_delegate` state variable. The signature authenticates whether the the caller can mint/purchase these Fragment Tokens
    /// @param `environment` - ¿
    function bid(bytes calldata signature, bytes calldata environment)
        external
        payable
    {
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

        bytes32 dataHash = keccak256(
            abi.encodePacked(_fragmentId, environment)
        );

        // Authenticate
        bytes32 hash = ECDSA.toEthSignedMessageHash(
            keccak256(abi.encodePacked(msg.sender, _getChainId(), dataHash))
        );
        require(
            _delegate != address(0x0) &&
                _delegate == ECDSA.recover(hash, signature),
            "Invalid signature"
        );

        // pay royalties
        _vault.deposit{value: msg.value}();

        // mint it
        _upload(dataHash, 1);
    }

    function currentBidPrice() external view returns (uint256) {
        assert(_publicMinting == DUTCH_MINTING);
        // reduce price over time via blocks
        uint256 blocksDiff = block.number - _dutchStartBlock;
        uint256 price = _publicMintingPrice - (_dutchStep * blocksDiff);
        return price;
    }

    function isMarketOpen() external view returns (bool) {
        return
            _publicMinting != NO_PUB_MINTING &&
            _tokenIds.current() < _publicCap;
    }

    /// @notice ¿Allow the Fragment(s) in this Contract to be Publicly Minted at price `price`? NOTE: ONLY THE OWNER OF THIS CONTRACT CAN CALL THIS FUNCTION
    /// @param price - The Minimum Price a Fragment can be bought for
    /// @param maxAmount - The maximum number of Fragments that can be bought in a single function call
    /// @param cap - The number of Fragments that are for sale
    function setPublicSale(
        uint256 price,
        uint96 maxAmount,
        uint96 cap
    ) external onlyOwner {
        _publicMinting = PUB_MINTING;
        _publicMintingPrice = price;
        _maxPublicAmount = maxAmount;
        _publicCap = cap;
        assert(_publicCap <= _maxSupply);
    }
    // A Dutch auction is one of several similar types of auctions for buying or selling goods.
    // Most commonly, it means an auction in which the auctioneer begins with a high asking price in the case of selling,
    // and lowers it until some participant accepts the price, or it reaches a predetermined reserve price.
    /// @notice ¿Allow the Fragment(s) in this Contract to be auctioned to the highest bigger (The exact auction type used is a Dutch Auction) NOTE: ONLY THE OWNER OF THIS CONTRACT CAN CALL THIS FUNCTION
    /// @param maxPrice - The starting price
    /// @param priceStep - The amount the price decreases at every time step
    /// @param slots - The number of Fragments that are for sale
    function openDutchAuction(
        uint256 maxPrice,
        uint256 priceStep,
        uint96 slots
    ) external onlyOwner {
        _publicMinting = DUTCH_MINTING;
        _publicMintingPrice = maxPrice;
        _dutchStartBlock = block.number;
        _dutchStep = priceStep;
        _publicCap = slots;
        assert(_publicCap <= _maxSupply);
    }

    /// @notice Stop public minting (i.e prevent further Fragments from being minted by anyone) NOTE: ONLY THE OWNER OF THIS CONTRACT CAN CALL THIS FUNCTION
    function stopMarket() external onlyOwner {
        _publicMinting = NO_PUB_MINTING;
    }

    /// @notice Transfer ERC-20 Token with token contract address `tokenAddress` and amount `tokenAmount` to `fragmentOwner()`.
    /// NOTE: ONLY THE CONTRACT OWNER CAN THIS CALL THIS FUNCTION
    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        onlyOwner
    {
        // notice: fragmentOwner, not owner due to owner used for opensea workaround...
        IERC20(tokenAddress).safeTransfer(fragmentOwner(), tokenAmount);
    }

    /// @notice Claim Ether that is held by this contract (i.e by this Vault Contract).
    /// NOTE: ONLY THE CONTRACT OWNER CAN THIS CALL THIS FUNCTION
    function recoverETH(uint256 amount) external onlyOwner {
        // notice: fragmentOwner, not owner due to owner used for opensea workaround...
        payable(fragmentOwner()).transfer(amount);
    }
}
