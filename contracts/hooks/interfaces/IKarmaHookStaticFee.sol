// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

interface IKarmaHookStaticFee {
    error KarmaFeeTooHigh();
    error PairedFeeTooHigh();

    event PoolInitialized(PoolId poolId, uint24 karmaFee, uint24 pairedFee);

    struct PoolStaticConfigVars {
        uint24 karmaFee;
        uint24 pairedFee;
    }

    function karmaFee(PoolId poolId) external view returns (uint24);
    function pairedFee(PoolId poolId) external view returns (uint24);
}
