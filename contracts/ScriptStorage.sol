pragma solidity ^0.8.0;

contract ScriptStorage {
    mapping(uint256 => bytes) internal _immutable;
    mapping(uint256 => bytes) internal _mutable;
}
