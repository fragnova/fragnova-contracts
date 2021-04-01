pragma solidity ^0.8.0;

contract ScriptStorageV0 {
    // mapping for scripts storage
    mapping(uint160 => bytes) internal _scripts;
    mapping(uint160 => bytes) internal _environments;
}
