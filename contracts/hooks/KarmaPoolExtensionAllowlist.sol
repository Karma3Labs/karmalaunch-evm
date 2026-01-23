// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IKarmaPoolExtensionAllowlist} from "./interfaces/IKarmaPoolExtensionAllowlist.sol";

import {OwnerAdmins} from "../utils/OwnerAdmins.sol";

contract KarmaPoolExtensionAllowlist is IKarmaPoolExtensionAllowlist, OwnerAdmins {
    mapping(address extension => bool enabled) public enabledExtensions;

    constructor(address owner_) OwnerAdmins(owner_) {}

    function setPoolExtension(address extension, bool enabled) external onlyOwnerOrAdmin {
        enabledExtensions[extension] = enabled;
        emit SetPoolExtension(extension, enabled);
    }
}
