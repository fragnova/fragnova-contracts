/* SPDX-License-Identifier: BUSL-1.1 */
/* Copyright © 2021 Fragcolor Pte. Ltd. */

pragma solidity ^0.8.7;

struct FragmentInitData {
    uint256 fragmentId;
    uint256 maxSupply;
    address fragmentsLibrary;
    address payable vault;
    bool unique;
    bool updateable;
}

interface IEntity {
    function fragmentOwner() external view returns (address);

    function bootstrap(
        string calldata tokenName,
        string calldata tokenSymbol,
        FragmentInitData calldata params
    ) external;
}
