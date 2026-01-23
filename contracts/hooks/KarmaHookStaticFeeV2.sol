// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {KarmaHookV2} from "./KarmaHookV2.sol";
import {IKarmaHookStaticFee} from "./interfaces/IKarmaHookStaticFee.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

contract KarmaHookStaticFeeV2 is KarmaHookV2, IKarmaHookStaticFee {
    mapping(PoolId => uint24) public karmaFee;
    mapping(PoolId => uint24) public pairedFee;

    constructor(
        address _poolManager,
        address _factory,
        address _poolExtensionAllowlist,
        address _weth
    ) KarmaHookV2(_poolManager, _factory, _poolExtensionAllowlist, _weth) {}

    function _initializeFeeData(PoolKey memory poolKey, bytes memory feeData) internal override {
        PoolStaticConfigVars memory _poolConfigVars = abi.decode(feeData, (PoolStaticConfigVars));

        if (_poolConfigVars.karmaFee > MAX_LP_FEE) {
            revert KarmaFeeTooHigh();
        }

        if (_poolConfigVars.pairedFee > MAX_LP_FEE) {
            revert PairedFeeTooHigh();
        }

        karmaFee[poolKey.toId()] = _poolConfigVars.karmaFee;
        pairedFee[poolKey.toId()] = _poolConfigVars.pairedFee;

        emit PoolInitialized(poolKey.toId(), _poolConfigVars.karmaFee, _poolConfigVars.pairedFee);
    }

    // set the LP fee according to the karma/paired fee configuration
    function _setFee(PoolKey calldata poolKey, IPoolManager.SwapParams calldata swapParams)
        internal
        override
    {
        uint24 fee = swapParams.zeroForOne != karmaIsToken0[poolKey.toId()]
            ? pairedFee[poolKey.toId()]
            : karmaFee[poolKey.toId()];

        _setProtocolFee(fee);
        IPoolManager(poolManager).updateDynamicLPFee(poolKey, fee);
    }
}
