pragma solidity ^0.8.0;

contract ScriptStorage {
    mapping(uint256 => bytes) internal _immutable;
    mapping(uint256 => bytes) internal _mutable;
    mapping(uint256 => uint160[]) internal _references;
    mapping(uint256 => uint256) internal _includeCost;
}
