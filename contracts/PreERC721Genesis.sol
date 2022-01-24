pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/proxy/utils/Initializable.sol";

contract PreERC721Genesis is Ownable, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public constant TOTAL_TOKENS = 100;

    EnumerableSet.UintSet private _excludedTokens;
    EnumerableSet.AddressSet private _excludedOwners;

    address private _controller;

    modifier onlyController() {
        require(msg.sender == _controller);
        _;
    }

    function getOwners() private pure returns (address[TOTAL_TOKENS] memory) {
        address[TOTAL_TOKENS] memory owners = [
            address(0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1),
            address(0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0),
            address(0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b),
            address(0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d),
            address(0xd03ea8624C8C5987235048901fB614fDcA89b117),
            address(0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC),
            address(0x3E5e9111Ae8eB78Fe1CC3bb8915d5D461F3Ef9A9),
            address(0x28a8746e75304c0780E011BEd21C72cD78cd535E),
            address(0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E),
            address(0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e),
            address(0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1),
            address(0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0),
            address(0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b),
            address(0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d),
            address(0xd03ea8624C8C5987235048901fB614fDcA89b117),
            address(0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC),
            address(0x3E5e9111Ae8eB78Fe1CC3bb8915d5D461F3Ef9A9),
            address(0x28a8746e75304c0780E011BEd21C72cD78cd535E),
            address(0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E),
            address(0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e),
            address(0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1),
            address(0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0),
            address(0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b),
            address(0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d),
            address(0xd03ea8624C8C5987235048901fB614fDcA89b117),
            address(0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC),
            address(0x3E5e9111Ae8eB78Fe1CC3bb8915d5D461F3Ef9A9),
            address(0x28a8746e75304c0780E011BEd21C72cD78cd535E),
            address(0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E),
            address(0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e),
            address(0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1),
            address(0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0),
            address(0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b),
            address(0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d),
            address(0xd03ea8624C8C5987235048901fB614fDcA89b117),
            address(0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC),
            address(0x3E5e9111Ae8eB78Fe1CC3bb8915d5D461F3Ef9A9),
            address(0x28a8746e75304c0780E011BEd21C72cD78cd535E),
            address(0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E),
            address(0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e),
            address(0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1),
            address(0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0),
            address(0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b),
            address(0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d),
            address(0xd03ea8624C8C5987235048901fB614fDcA89b117),
            address(0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC),
            address(0x3E5e9111Ae8eB78Fe1CC3bb8915d5D461F3Ef9A9),
            address(0x28a8746e75304c0780E011BEd21C72cD78cd535E),
            address(0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E),
            address(0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e),
            address(0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1),
            address(0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0),
            address(0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b),
            address(0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d),
            address(0xd03ea8624C8C5987235048901fB614fDcA89b117),
            address(0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC),
            address(0x3E5e9111Ae8eB78Fe1CC3bb8915d5D461F3Ef9A9),
            address(0x28a8746e75304c0780E011BEd21C72cD78cd535E),
            address(0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E),
            address(0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e),
            address(0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1),
            address(0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0),
            address(0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b),
            address(0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d),
            address(0xd03ea8624C8C5987235048901fB614fDcA89b117),
            address(0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC),
            address(0x3E5e9111Ae8eB78Fe1CC3bb8915d5D461F3Ef9A9),
            address(0x28a8746e75304c0780E011BEd21C72cD78cd535E),
            address(0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E),
            address(0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e),
            address(0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1),
            address(0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0),
            address(0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b),
            address(0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d),
            address(0xd03ea8624C8C5987235048901fB614fDcA89b117),
            address(0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC),
            address(0x3E5e9111Ae8eB78Fe1CC3bb8915d5D461F3Ef9A9),
            address(0x28a8746e75304c0780E011BEd21C72cD78cd535E),
            address(0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E),
            address(0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e),
            address(0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1),
            address(0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0),
            address(0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b),
            address(0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d),
            address(0xd03ea8624C8C5987235048901fB614fDcA89b117),
            address(0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC),
            address(0x3E5e9111Ae8eB78Fe1CC3bb8915d5D461F3Ef9A9),
            address(0x28a8746e75304c0780E011BEd21C72cD78cd535E),
            address(0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E),
            address(0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e),
            address(0x90F8bf6A479f320ead074411a4B0e7944Ea8c9C1),
            address(0xFFcf8FDEE72ac11b5c542428B35EEF5769C409f0),
            address(0x22d491Bde2303f2f43325b2108D26f1eAbA1e32b),
            address(0xE11BA2b4D45Eaed5996Cd0823791E0C93114882d),
            address(0xd03ea8624C8C5987235048901fB614fDcA89b117),
            address(0x95cED938F7991cd0dFcb48F0a06a40FA1aF46EBC),
            address(0x3E5e9111Ae8eB78Fe1CC3bb8915d5D461F3Ef9A9),
            address(0x28a8746e75304c0780E011BEd21C72cD78cd535E),
            address(0xACa94ef8bD5ffEE41947b4585a84BdA5a3d3DA6E),
            address(0x1dF62f291b2E969fB0849d99D9Ce41e2F137006e)
        ];
        return owners;
    }

    function getCids() private pure returns (bytes32[TOTAL_TOKENS] memory) {
        bytes32[100] memory cids = [
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            ),
            bytes32(
                0x953f867f5e7af34b031d2689ea1486420571dfac0cd4043b173b0035e621c0dd
            )
        ];
        return cids;
    }

    function getGenesisOwner(uint256 tokenId) public view returns (address) {
        if (_excludedTokens.contains(tokenId)) {
            return address(0x0);
        } else if (tokenId > 0 && tokenId <= TOTAL_TOKENS) {
            address[TOTAL_TOKENS] memory owners = getOwners();
            return owners[tokenId - 1];
        } else {
            return address(0x0);
        }
    }

    function isGenesisToken(uint256 tokenId) external view returns (bool) {
        return getGenesisOwner(tokenId) != address(0x0);
    }

    function getGenesisBalance(address tokenOwner)
        external
        view
        returns (uint256)
    {
        uint256 amount = 0;
        if (!_excludedOwners.contains(tokenOwner)) {
            address[TOTAL_TOKENS] memory owners = getOwners();
            for (uint256 i = 0; i < TOTAL_TOKENS; i++) {
                if (
                    owners[i] == tokenOwner && !_excludedTokens.contains(i + 1)
                ) {
                    amount++;
                }
            }
        }
        return amount;
    }

    function exclude(uint256 tokenId, address tokenOwner)
        external
        onlyController
    {
        _excludedTokens.add(tokenId);

        // We need to support owners owning multiple tokens.
        address[TOTAL_TOKENS] memory owners = getOwners();
        for (uint256 i = 0; i < TOTAL_TOKENS; i++) {
            uint256 tId = i + 1;
            if (
                owners[i] == tokenOwner &&
                tId != tokenId &&
                !_excludedTokens.contains(tId)
            ) {
                return;
            }
        }
        _excludedOwners.add(tokenOwner);
    }

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    function generateEvents() external onlyController {
        address[TOTAL_TOKENS] memory owners = getOwners();
        for (uint256 i = 0; i < TOTAL_TOKENS; i++) {
            emit Transfer(address(0x0), owners[i], i + 1);
        }
    }

    function getCid(uint256 tokenId) external pure returns (bytes32) {
        assert(tokenId > 0 && tokenId <= TOTAL_TOKENS);
        bytes32[TOTAL_TOKENS] memory cids = getCids();
        return cids[tokenId - 1];
    }

    function init(address controller) external onlyOwner initializer {
        _controller = controller;
    }
}
