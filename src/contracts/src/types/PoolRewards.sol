// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolRewardsLib} from "../libraries/PoolRewardsLib.sol";

using PoolRewardsLib for PoolRewards global;

struct PoolRewards {
    uint256 growthGlobalX128;
    mapping(int24 => uint256) tickGrowthOutside;
    int24 priorTick;
}