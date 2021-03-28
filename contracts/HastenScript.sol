pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";
import "./Ownable.sol";

contract HastenScript is ERC721, Ownable, Initializable {
    using SafeERC20 for IERC20;

    // rewards related
    uint256 internal _mintReward = 1 * (10**16);
    mapping(address => uint256) private _rewardBlocks;
    IERC20 internal _daoToken = IERC20(address(0));

    // mapping for ipfs metadata, storing just 32 bytes of the CIDv0 (minus multihash prefix)
    mapping(uint160 => bytes32) private _ipfsMetadataV0;

    // mapping for scripts storage
    mapping(uint160 => bytes) private _scripts;
    mapping(uint160 => bytes) private _environments;

    constructor()
        ERC721("Hasten Script v0 NFT", "CODE")
        Ownable(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974))
    {
        // NOT INVOKED
    }

    function bootstrap() public payable initializer {
        // Ownable
        Ownable._bootstrap(address(0x7F7eF2F9D8B0106cE76F66940EF7fc0a3b23C974));
        // ERC721
        _name = "Hasten Script v0 NFT";
        _symbol = "CODE";
    }

    function reverse(uint8[] memory input)
        private
        pure
        returns (uint8[] memory)
    {
        uint8[] memory output = new uint8[](input.length);
        for (uint32 i = 0; i < input.length; i++) {
            output[i] = input[input.length - 1 - i];
        }
        return output;
    }

    bytes constant ALPHABET =
        "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

    function toAlphabet(uint8[] memory indices)
        private
        pure
        returns (bytes memory)
    {
        bytes memory output = new bytes(indices.length);
        for (uint32 i = 0; i < indices.length; i++) {
            output[i] = ALPHABET[indices[i]];
        }
        return output;
    }

    function toBase58(bytes memory source) private pure returns (bytes memory) {
        if (source.length == 0) return new bytes(0);
        uint8[] memory digits = new uint8[](46);
        digits[0] = 0;
        uint8 digitlength = 1;
        for (uint32 i = 0; i < source.length; ++i) {
            uint256 carry = uint8(source[i]);
            for (uint32 j = 0; j < digitlength; ++j) {
                carry += uint256(digits[j]) * 256;
                digits[j] = uint8(carry % 58);
                carry = carry / 58;
            }

            while (carry > 0) {
                digits[digitlength] = uint8(carry % 58);
                digitlength++;
                carry = carry / 58;
            }
        }
        return toAlphabet(reverse(digits));
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

        bytes32 cidBytes = _ipfsMetadataV0[uint160(tokenId)];
        return
            string(
                abi.encodePacked(
                    "ipfs://",
                    toBase58(
                        abi.encodePacked(uint8(0x12), uint8(0x20), cidBytes)
                    )
                )
            );
    }

    function script(uint160 scriptHash)
        public
        view
        returns (bytes memory scriptBytes, bytes memory environment)
    {
        return (_scripts[scriptHash], _environments[scriptHash]);
    }

    function upload(
        bytes32 ipfsMetadata,
        bytes memory scriptBytes,
        bytes memory environment
    ) public {
        // mint a new token and upload it
        // but make scripts unique by hashing them
        uint160 hash = uint160(uint256(keccak256(scriptBytes)));
        require(!_exists(hash), "HastenScript: script already minted");

        _mint(msg.sender, hash);

        _ipfsMetadataV0[hash] = ipfsMetadata;
        _scripts[hash] = scriptBytes;
        _environments[hash] = environment;
    }

    function update(
        uint160 scriptHash,
        bytes32 ipfsMetadata,
        bytes memory environment
    ) public {
        require(
            _exists(scriptHash) && msg.sender == ownerOf(scriptHash),
            "HastenScript: Only the owner of the script can update it"
        );

        _ipfsMetadataV0[scriptHash] = ipfsMetadata;
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
                _daoToken.safeIncreaseAllowance(address(this), _mintReward);
                _daoToken.safeTransferFrom(
                    address(this),
                    msg.sender,
                    _mintReward
                );
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
