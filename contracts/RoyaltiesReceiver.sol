/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

import "openzeppelin-solidity/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title This contract essentially is an ERC-2981 Contract (https://www.youtube.com/watch?v=h6Fb_dPZCd0)
contract RoyaltiesReceiver {
    using SafeERC20 for IERC20;

    // The Proto-Fragment owner will get 7% royalty of the sales price, for any and all sales
    uint256 public constant FRAGMENT_ROYALTIES_BPS = 700;

    bytes4 private constant _INTERFACE_ID_ROYALTIES_CREATORCORE = 0xbb3bafd6;
    // Interface ID of the function `royaltyInfo`  (https://eips.ethereum.org/EIPS/eip-2981)
    // bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
    bytes4 private constant _INTERFACE_ID_ROYALTIES_EIP2981 = 0x2a55205a;
    /* Inteface ID of `getFeeBps` and `getFeeRecipients` (https://docs.rarible.org/ethereum/smart-contracts/royalties/)
    * bytes4(keccak256('getFeeBps(uint256)')) == 0x0ebd4c7f
    * bytes4(keccak256('getFeeRecipients(uint256)')) == 0xb9c4d9fb
    *
    * => 0x0ebd4c7f ^ 0xb9c4d9fb == 0xb7799584
    */
    bytes4 private constant _INTERFACE_ID_ROYALTIES_RARIBLE = 0xb7799584;

    bytes32 private constant SLOT_royaltiesRecipient =
        bytes32(
            uint256(
                keccak256("fragments.RoyaltiesReceiver.royaltiesRecipient")
            ) - 1
        );
    bytes32 private constant SLOT_royaltiesBps =
        bytes32(
            uint256(keccak256("fragments.RoyaltiesReceiver.royaltiesBps")) - 1
        );

    /// @notice Returns the address of the Royalties Recipient
    function getRoyaltiesRecipient()
        private
        view
        returns (address payable dest)
    {
        bytes32 slot = SLOT_royaltiesRecipient;
        assembly {
            dest := sload(slot)
        }
    }

    /// @notice Returns the basis points of the Sales Price that will go to the Royalties Recipient
    function getRoyaltiesBps() private view returns (uint256 bps) {
        bytes32 slot = SLOT_royaltiesBps;
        assembly {
            bps := sload(slot)
        }
    }


    /// @notice Sets up the Royalties Recipient (`royaltiesRecipient`) and the basis points of the Sales Price that will go to the Royalties Recipient (`royaltiesBps`)
    /// @param royaltiesRecipient - The Royalties Recipient
    /// @param royaltiesBps - The basis points of the Sales Price that will go to the Royalties Recipient
    function setupRoyalties(
        address payable royaltiesRecipient,
        uint256 royaltiesBps
    ) internal {
        bytes32 slot = SLOT_royaltiesRecipient;
        assembly {
            sstore(slot, royaltiesRecipient)
        }

        slot = SLOT_royaltiesBps;
        assembly {
            sstore(slot, royaltiesBps)
        }
    }

    /// @dev This is a mandatory function that must be implemented by an ERC-2981 Contract (https://www.youtube.com/watch?v=h6Fb_dPZCd0)
    function _supportsInterface(bytes4 interfaceId)
        internal
        pure
        returns (bool)
    {
        return
            interfaceId == _INTERFACE_ID_ROYALTIES_CREATORCORE ||
            interfaceId == _INTERFACE_ID_ROYALTIES_EIP2981 ||
            interfaceId == _INTERFACE_ID_ROYALTIES_RARIBLE;
    }

    /// @notice Returns the Royalties Recipients and their respective Royalties BPS of this Smart Contract
    /// @param uint256 - The first parameter is not used
    function getRoyalties(uint256)
        external
        view
        returns (address payable[] memory recipients, uint256[] memory bps)
    {
        recipients = new address payable[](1);
        recipients[0] = getRoyaltiesRecipient();
        bps = new uint256[](1);
        bps[0] = getRoyaltiesBps();
        return (recipients, bps);
    }

    /// @notice Returns a list of addresses of the Royalties Recipients (the length of the list is always one for this Smart Contract)
    function getFeeRecipients(uint256)
        external
        view
        returns (address payable[] memory recipients)
    {
        recipients = new address payable[](1);
        recipients[0] = getRoyaltiesRecipient();
        return recipients;
    }

    /// @notice Returns a list of BPS values (that represent the Royalty Rate) of the Royalties Recipients (the length of the list is always one for this Smart Contract)
    function getFeeBps(uint256) external view returns (uint256[] memory bps) {
        bps = new uint256[](1);
        bps[0] = getRoyaltiesBps();
        return bps;
    }


    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param uint256 - The first parameter is not used, that's why it's unnamed. (However, usually the first parameter is the token ID of the NFT asset queried for royalty information)
    /// @param value - the sale price of the NFT asset specified by _tokenId
    /// @return receiver - address of who should be sent the royalty payment
    /// @return royaltyAmount - the royalty payment amount for _salePrice
    /// @dev Currently, the `royaltyAmount` is `getRoyaltiesBps()` multiplied by `value`
    /// @dev This is a mandatory function that must be implemented by an ERC-2981 Contract (https://www.youtube.com/watch?v=h6Fb_dPZCd0)
    function royaltyInfo(uint256, uint256 value)
        external
        view
        returns (address, uint256)
    {
        return (getRoyaltiesRecipient(), (value * getRoyaltiesBps()) / 10000);
    }
}
