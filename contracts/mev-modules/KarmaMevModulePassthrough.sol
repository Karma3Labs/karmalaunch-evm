// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IKarmaMevModule} from "../interfaces/IKarmaMevModule.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

/// @title KarmaMevModulePassthrough
/// @notice A simple MEV module that allows all swaps without any restrictions
/// @dev This module is useful for pools that don't need MEV protection
contract KarmaMevModulePassthrough is IKarmaMevModule {
    /// @notice The hook address that can call this module
    address public immutable hook;

    /// @notice Emitted when the module is initialized for a pool
    event Initialized(bytes32 indexed poolId);

    constructor(address _hook) {
        hook = _hook;
    }

    /// @notice Initialize the MEV module for a pool
    /// @dev Called by the hook during pool initialization
    /// @param poolKey The pool key
    /// @param mevModuleInitData Initialization data (unused in passthrough)
    function initialize(
        PoolKey calldata poolKey,
        bytes calldata mevModuleInitData
    ) external override {
        // Only the hook can initialize
        if (msg.sender != hook) {
            revert OnlyHook();
        }

        // Passthrough module doesn't need any initialization
        // Just emit event for tracking
        emit Initialized(keccak256(abi.encode(poolKey)));
    }

    /// @notice Called before each swap - always allows the swap
    /// @dev Returns false to indicate MEV module should NOT be disabled
    /// @param poolKey The pool key (unused)
    /// @param swapParams The swap parameters (unused)
    /// @param karmaIsToken0 Whether karma is token0 (unused)
    /// @param mevModuleSwapData Additional swap data (unused)
    /// @return disableMevModule Always returns false (don't disable)
    function beforeSwap(
        PoolKey calldata poolKey,
        IPoolManager.SwapParams calldata swapParams,
        bool karmaIsToken0,
        bytes calldata mevModuleSwapData
    ) external override returns (bool disableMevModule) {
        // Only the hook can call beforeSwap
        if (msg.sender != hook) {
            revert OnlyHook();
        }

        // Passthrough: allow all swaps, don't disable the module
        return false;
    }

    /// @notice Check if this contract supports the IKarmaMevModule interface
    /// @param interfaceId The interface identifier
    /// @return True if the interface is supported
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IKarmaMevModule).interfaceId;
    }
}
