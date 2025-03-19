// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IStaking } from "./interfaces/IStaking.sol";
import { IToken } from "./interfaces/IToken.sol";
import { KKToken } from "./KKToken.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Staking is IStaking, Ownable, ReentrancyGuard {
  KKToken public immutable token;
  // 每区块奖励数量
  uint256 public constant R = 10e18;
  // 最小质押数量
  uint256 public constant MINIMUM_STAKE = 0.01 ether;

  struct StakeInfo {
    uint256 amount;
    uint256 rewardDebt; // 记录已结算的奖励
    uint256 pending; // 待领取的奖励
  }

  mapping(address => StakeInfo) public stakes;

  // 总质押数
  uint256 public totalStaked;
  // 利率
  uint256 public rate;
  // 上次更新区块
  uint256 public lastUpdateBlock;

  event Staked(address indexed user, uint256 amount);
  event Unstaked(address indexed user, uint256 amount);
  event RewardsClaimed(address indexed user, uint256 amount);

  constructor() Ownable(msg.sender) {
    token = new KKToken();
    lastUpdateBlock = block.number;
  }

  /**
   * @dev 更新累计总奖励
   */
  function _updatePool() internal {
    if (block.number <= lastUpdateBlock) return;
    if (totalStaked == 0) {
      lastUpdateBlock = block.number;
      return;
    }

    uint256 blocks = block.number - lastUpdateBlock;
    //累计利率
    rate += (blocks * R) / totalStaked;
    lastUpdateBlock = block.number;
  }

  /**
   * @dev 计算用户待结算的奖励
   */
  function _calculatePending(address user) internal view returns (uint256) {
    return (stakes[user].amount * rate) - stakes[user].rewardDebt;
  }

  /**
   * @dev 更新用户奖励状态
   */
  function _updateUserReward(address user) internal {
    uint256 pending = _calculatePending(user);
    if (pending > 0) {
      stakes[user].pending += pending;
    }
    stakes[user].rewardDebt = stakes[user].amount * rate;
  }

  /**
   * @dev 质押 ETH 到合约
   */
  function stake() external payable nonReentrant {
    require(msg.value >= MINIMUM_STAKE, "Staking: amount below minimum stake");

    _updatePool();

    // 更新现有奖励
    if (stakes[msg.sender].amount > 0) {
      _updateUserReward(msg.sender);
    }

    stakes[msg.sender].amount += msg.value;
    totalStaked += msg.value;
    stakes[msg.sender].rewardDebt = stakes[msg.sender].amount * rate;

    emit Staked(msg.sender, msg.value);
  }

  /**
   * @dev 赎回质押的 ETH
   * @param amount 赎回数量
   */
  function unstake(uint256 amount) external nonReentrant {
    require(stakes[msg.sender].amount >= amount, "Staking: insufficient balance");

    _updatePool();
    _updateUserReward(msg.sender);

    stakes[msg.sender].amount -= amount;
    totalStaked -= amount;
    stakes[msg.sender].rewardDebt = stakes[msg.sender].amount * rate;

    (bool success,) = msg.sender.call{ value: amount }("");
    require(success, "Transfer failed");

    emit Unstaked(msg.sender, amount);
  }

  /**
   * @dev 领取 KK Token 收益
   */
  function claim() external nonReentrant {
    _updatePool();
    _updateUserReward(msg.sender);

    uint256 totalPending = stakes[msg.sender].pending;
    require(totalPending > 0, "No rewards to claim");

    stakes[msg.sender].pending = 0;
    token.mint(msg.sender, totalPending);

    emit RewardsClaimed(msg.sender, totalPending);
  }

  /**
   * @dev 获取质押的 ETH 数量
   */
  function balanceOf(address account) external view returns (uint256) {
    return stakes[account].amount;
  }

  /**
   * @dev 获取待领取的 KK Token 收益
   */
  function earned(address account) external view returns (uint256) {
    StakeInfo memory stake = stakes[account];
    uint256 _rate = rate;

    if (block.number > lastUpdateBlock && totalStaked != 0) {
      uint256 blocks = block.number - lastUpdateBlock;
      _rate += (blocks * R) / totalStaked;
    }

    return stake.pending + ((stake.amount * _rate) - stake.rewardDebt);
  }
}
