// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {KarmaToken} from "../KarmaToken.sol";
import {IKarma} from "../interfaces/IKarma.sol";

/// @notice Karma Token Launcher
library KarmaDeployer {
    function deployToken(IKarma.TokenConfig memory tokenConfig, uint256 supply)
        external
        returns (address tokenAddress)
    {
        KarmaToken token = new KarmaToken{
            salt: keccak256(abi.encode(tokenConfig.tokenAdmin, tokenConfig.salt))
        }(
            tokenConfig.name,
            tokenConfig.symbol,
            supply,
            tokenConfig.tokenAdmin,
            tokenConfig.image,
            tokenConfig.metadata,
            tokenConfig.context,
            tokenConfig.originatingChainId
        );
        tokenAddress = address(token);
    }
}
