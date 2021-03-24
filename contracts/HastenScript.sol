pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "./Ownable.sol";

contract HastenScript is ERC721URIStorage, Ownable, Initializable {
    // rewards related
    uint256 internal _mintReward = 1 * (10**16);
    mapping(address => uint256) private _rewardBlocks;
    IERC20 internal _daoToken = IERC20(address(0));

    // mapping for scripts storage
    mapping(uint160 => bytes) private _scripts;
    mapping(uint160 => bytes) private _environments;

    constructor()
        ERC721("Hasten Script NFT v0", "CODE")
        Ownable(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974))
    {}

    function bootstrap() public payable initializer {
        // Ownable
        Ownable._bootstrap(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974));
        // ERC721
        _name = "Hasten Script NFT v0";
        _symbol = "CODE";
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://";
    }

    function script(uint160 scriptHash)
        public
        view
        returns (bytes memory scriptBytes, bytes memory environment)
    {
        return (_scripts[scriptHash], _environments[scriptHash]);
    }

    function upload(string memory tokenURI, bytes memory scriptBytes) public {
        bytes memory empty = new bytes(0);
        uploadWithEnvironment(tokenURI, scriptBytes, empty);
    }

    function uploadWithEnvironment(
        string memory tokenURI,
        bytes memory scriptBytes,
        bytes memory environment
    ) public {
        // mint a new token and upload it
        // but make scripts unique by hashing them
        // keccak256 seems the cheapest hashing function
        uint160 hash = uint160(uint256(keccak256(scriptBytes)));
        require(!_exists(hash), "HastenScript: script already minted");

        _mint(msg.sender, hash);

        _scripts[hash] = scriptBytes;
        _environments[hash] = environment;
        _setTokenURI(hash, tokenURI);
    }

    function update(uint160 scriptHash, bytes memory environment) public {
        require(
            _exists(scriptHash) && msg.sender == ownerOf(scriptHash),
            "Only the owner of the script can update its environment"
        );
        _environments[scriptHash] = environment;
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
                _daoToken.balanceOf(address(this)) > _mintReward
            ) {
                _daoToken.approve(address(this), _mintReward);
                _daoToken.transferFrom(address(this), msg.sender, _mintReward);
                _rewardBlocks[msg.sender] = block.number;
            }
        }
    }

    function setMintReward(uint256 amount) public onlyOwner {
        _mintReward = amount;
    }

    function getMintReward() public view returns (uint256) {
        return _mintReward;
    }

    function setDAOToken(address addr) public onlyOwner {
        _daoToken = IERC20(addr);
    }

    function getDAOToken() public view returns (address) {
        return address(_daoToken);
    }
}
