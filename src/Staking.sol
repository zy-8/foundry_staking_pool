// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IStaking } from "./interfaces/IStaking.sol";
import { IToken } from "./interfaces/IToken.sol";
import { KKToken } from "./KKToken.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Staking is IStaking, Ownable, ReentrancyGuard {
  KKToken public immutable token;
  uint256 public constant R = 10 ether;         // 每区块奖励 10 个代币
  uint256 public constant UNITS = 1e18;         // 精度单位
  uint256 public constant MINIMUM_STAKE = 0.01 ether;

  struct StakeInfo {
    uint256 amount;     // 质押数量
    uint256 index;      // 用户最后更新时的累积指数
    uint256 debt;       // 待领取的奖励
  }

  struct PoolInfo {
    uint256 totalStaked;        // 总质押量
    uint256 index;              // 全局累积指数
    uint256 lastUpdateBlock;    // 上次更新区块
  }

  mapping(address => StakeInfo) public stakes;
  PoolInfo public pool;

  event Staked(address indexed user, uint256 amount);
  event Unstaked(address indexed user, uint256 amount);
  event RewardsClaimed(address indexed user, uint256 amount);

  constructor() Ownable(msg.sender) {
    token = new KKToken();
    pool.lastUpdateBlock = block.number;
  }

  function _updatePool() internal {
    if (pool.totalStaked == 0) return;
    uint256 blockDelta = block.number - pool.lastUpdateBlock;
    uint256 rewards = blockDelta * R;// 总奖励 = 区块数 * 每区块奖励
    pool.index += (rewards * UNITS) / pool.totalStaked;
    pool.lastUpdateBlock = block.number;
  }

  function _indexNow() internal view returns (uint256) {
    if (pool.totalStaked == 0) return pool.index;
    uint256 blockDelta = block.number - pool.lastUpdateBlock;
    uint256 rewards = blockDelta * R;
    return pool.index + ((rewards * UNITS) / pool.totalStaked);
  }

  function _updateStake(address user) internal {
    uint256 newIndex = _indexNow();
    if (stakes[user].amount > 0) {
      uint256 reward = (stakes[user].amount * (newIndex - stakes[user].index)) / UNITS;
      if (reward > 0) {
        stakes[user].debt += reward;  // 累积到debt中
      }
    }
    stakes[user].index = newIndex;
    pool.index = newIndex;
    pool.lastUpdateBlock = block.number;
  }

  function stake() external payable nonReentrant {
    require(msg.value >= MINIMUM_STAKE, "Staking: amount below minimum stake");
    
    _updateStake(msg.sender);
    
    stakes[msg.sender].amount += msg.value;
    pool.totalStaked += msg.value;
    
    emit Staked(msg.sender, msg.value);
  }

  function unstake(uint256 amount) external nonReentrant {
    require(stakes[msg.sender].amount >= amount, "Staking: insufficient balance");
    
    _updateStake(msg.sender);
    
    stakes[msg.sender].amount -= amount;
    pool.totalStaked -= amount;
    
    (bool success,) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
    
    emit Unstaked(msg.sender, amount);
  }

  function claim() external nonReentrant {
    _updateStake(msg.sender);
    
    uint256 reward = stakes[msg.sender].debt;
    require(reward > 0, "No rewards to claim");
    
    stakes[msg.sender].debt = 0;  // 清零待领取奖励
    token.mint(msg.sender, reward);
    
    emit RewardsClaimed(msg.sender, reward);
  }

  function earned(address account) external view returns (uint256) {
    if (stakes[account].amount == 0) return 0;
    uint256 currentIndex = _indexNow();
    uint256 pendingReward = (stakes[account].amount * (currentIndex - stakes[account].index)) / UNITS;
    return stakes[account].debt + pendingReward;  // 已累积的 + 未更新的奖励
  }

  function balanceOf(address account) external view returns (uint256) {
    return stakes[account].amount;
  }
}
