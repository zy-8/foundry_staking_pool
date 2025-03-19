// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test, console } from "forge-std/Test.sol";
import { Staking } from "../src/Staking.sol";
import { KKToken } from "../src/KKToken.sol";

contract StakingTest is Test {
  Staking public staking;
  KKToken public kkToken;
  address public alice = makeAddr("Alice");
  address public bob = makeAddr("Bob");
  address public charlie = makeAddr("Charlie");

  function setUp() public {
    staking = new Staking();
    kkToken = staking.token();
    vm.deal(alice, 100 ether);
    vm.deal(bob, 100 ether);
    vm.deal(charlie, 100 ether);
  }

  function test_stake() public {
    vm.prank(alice);
    staking.stake{ value: 1 ether }();
    assertEq(staking.balanceOf(alice), 1 ether);
  }

  function test_unstake() public {
    vm.prank(alice);
    staking.stake{ value: 1 ether }();
    vm.prank(alice);
    staking.unstake(1 ether);
    assertEq(staking.balanceOf(alice), 0 ether);
  }

  function test_claim() public {
    vm.startPrank(alice);
    staking.stake{ value: 5 ether }();
    vm.roll(block.number + 10);
    vm.stopPrank();

    vm.startPrank(bob);
    staking.stake{ value: 5 ether }();
    vm.roll(block.number + 10);
    vm.stopPrank();

    vm.prank(alice);
    staking.claim();

    vm.prank(bob);
    staking.claim();

    console.log("alice balance", kkToken.balanceOf(alice));
    console.log("bob balance", kkToken.balanceOf(bob));

    assertEq(kkToken.balanceOf(alice), 150 ether);
    assertEq(kkToken.balanceOf(bob), 50 ether);
  }
}
