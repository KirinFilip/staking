// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import {StakingRewards} from "../src/StakingRewards.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract Constructor is Test {
    ERC20 public stakingToken;
    ERC20 public rewardsToken;
    StakingRewards public stakingRewards;

    function test_InitializeTokensCorrectly() public {
        stakingToken = new ERC20("Staking Token", "STAKE");
        rewardsToken = new ERC20("Rewards Token", "RWRD");
        stakingRewards = new StakingRewards(
            address(stakingToken),
            address(rewardsToken)
        );
        assertEq(stakingRewards.owner(), address(this));
        assertEq(address(stakingRewards.stakingToken()), address(stakingToken));
        assertEq(address(stakingRewards.rewardsToken()), address(rewardsToken));
    }
}

contract SetRewardsDuration is Test {
    ERC20 public stakingToken;
    ERC20 public rewardsToken;
    StakingRewards public stakingRewards;

    address alice = makeAddr("Alice");

    function setUp() public {
        stakingToken = new ERC20("Staking Token", "STAKE");
        rewardsToken = new ERC20("Rewards Token", "RWRD");
        stakingRewards = new StakingRewards(
            address(stakingToken),
            address(rewardsToken)
        );

        deal(address(rewardsToken), address(stakingRewards), 1_000_000e18);
    }

    function testFuzz_SetRewardsDuration(uint256 duration) public {
        stakingRewards.setRewardsDuration(duration);
        assertEq(stakingRewards.duration(), duration);
    }

    function test_RevertWhenNotOwner() public {
        vm.prank(alice);
        vm.expectRevert("not owner");
        stakingRewards.setRewardsDuration(1);
    }

    function test_RevertIfRewardDurationNotFinished() public {
        stakingRewards.setRewardsDuration(1 days);
        stakingRewards.notifyRewardAmount(1e18);
        vm.expectRevert("reward duration not finished");
        stakingRewards.setRewardsDuration(1 days);
    }
}

contract NotifyRewardAmount is Test {
    ERC20 public stakingToken;
    ERC20 public rewardsToken;
    StakingRewards public stakingRewards;

    address alice = makeAddr("Alice");

    uint256 rewardsTokenAmount = 1_000_000e18;

    function setUp() public {
        stakingToken = new ERC20("Staking Token", "STAKE");
        rewardsToken = new ERC20("Rewards Token", "RWRD");
        stakingRewards = new StakingRewards(
            address(stakingToken),
            address(rewardsToken)
        );

        deal(
            address(rewardsToken),
            address(stakingRewards),
            rewardsTokenAmount
        );
    }

    function test_RevertIfDurationNotSet() public {
        vm.expectRevert();
        stakingRewards.notifyRewardAmount(1e18);
    }

    function testFuzz_notifyRewardAmount(
        uint256 duration,
        uint256 amount
    ) public {
        duration = bound(duration, 1, rewardsTokenAmount);
        amount = bound(amount, 1, rewardsTokenAmount / duration);
        stakingRewards.setRewardsDuration(duration);
        stakingRewards.notifyRewardAmount(amount);
    }

    function test_RevertIfRewardRateZero() public {
        stakingRewards.setRewardsDuration(1 days);
        vm.expectRevert("reward rate = 0");
        stakingRewards.notifyRewardAmount(0);
    }

    function test_RevertIfRewardRateBiggerThanContractBalance() public {
        uint256 duration = 1 days;
        stakingRewards.setRewardsDuration(duration);
        vm.expectRevert("rewards amount > balance");
        stakingRewards.notifyRewardAmount(rewardsTokenAmount / duration + 1);
    }
}
