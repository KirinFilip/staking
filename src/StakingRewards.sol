// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract StakingRewards {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice token user deposits for staking
    IERC20 public immutable stakingToken;
    /// @notice token user can withdraw for depositing the staking token
    IERC20 public immutable rewardsToken;
    /// @notice owner of the contract
    address public immutable owner;

    /// @notice duration of which the rewards token accumulates
    uint256 public duration;
    /// @notice time when rewards token stops accumulating
    uint256 public finishAt;
    /// @notice last time this contract was updated
    uint256 public updatedAt;
    /// @notice rewards that the user gets per second
    uint256 public rewardRate;
    /// @notice reward token per staking token
    uint256 public rewardPerTokenStored;
    /// @notice rewards per token stored for a specific user
    mapping(address => uint256) public userRewardPerTokenPaid;
    /// @notice tracks rewards a user has earned
    mapping(address => uint256) public rewards;

    /// @notice totalSupply of the staking token
    uint256 public totalSupply;
    /// @notice staking token per user
    mapping(address => uint256) public balanceOf;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Stake(address user, uint256 amount);
    event Withdraw(address user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    modifier updateReward(address _account) {
        rewardPerTokenStored = rewardPerToken();
        updatedAt = lastTimeRewardApplicable();

        if (_account != address(0)) {
            rewards[_account] = earned(_account);
            userRewardPerTokenPaid[_account] = rewardPerTokenStored;
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(address _stakingToken, address _rewardsToken) {
        owner = msg.sender;
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardsToken);
    }

    /// @notice Set the duration which the reward token will be accumulating
    /// @dev Only the owner of this contract can call this function
    /// @param _duration The duration in seconds
    function setRewardsDuration(uint256 _duration) external onlyOwner {
        require(finishAt < block.timestamp, "reward duration not finished");
        duration = _duration;
    }

    /// @notice Specify the reward rate
    /// @dev Only owner is able to set reward rate
    /// @param _amount amount of rewards to be paid for the duration
    function notifyRewardAmount(
        uint256 _amount
    ) external onlyOwner updateReward(address(0)) {
        if (block.timestamp > finishAt) {
            rewardRate = (_amount * duration) / duration;
        } else {
            // remainingRewards = rewardRate * amount of time until rewards end
            uint256 remainingRewards = rewardRate *
                (finishAt - block.timestamp);

            rewardRate = (remainingRewards + _amount * duration) / duration;
        }

        require(rewardRate > 0, "reward rate = 0");
        // check that there is enough rewardsToken in the contract to be able to pay out
        require(
            rewardRate * duration <= rewardsToken.balanceOf(address(this)),
            "rewards amount > balance"
        );

        finishAt = block.timestamp + duration;
        updatedAt = block.timestamp;
    }

    /// @notice Stake staking tokens to be able to get rewards
    /// @param _amount amount of staking token to deposit
    function stake(uint256 _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        balanceOf[msg.sender] = balanceOf[msg.sender] + _amount;
        totalSupply = totalSupply + _amount;

        emit Stake(msg.sender, _amount);
    }

    /// @notice Withdraw tokens a user has staked
    /// @param _amount amount of staking token to withdraw
    function withdraw(uint256 _amount) external updateReward(msg.sender) {
        require(_amount > 0, "amount = 0");

        balanceOf[msg.sender] = balanceOf[msg.sender] - _amount;
        totalSupply = totalSupply - _amount;

        stakingToken.transfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return _min(block.timestamp, finishAt);
    }

    /// @notice Get reward amount per one staking token
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - updatedAt) * 1e18) /
            totalSupply;
    }

    /// @notice Get the earned amount of tokens for '_account'
    /// @param _account Address of the staker
    /// @return Amount of rewards that was earned by the '_account'
    function earned(address _account) public view returns (uint256) {
        return
            (balanceOf[_account] *
                (rewardPerToken() - userRewardPerTokenPaid[_account])) /
            1e18 +
            rewards[_account];
    }

    /// @notice Claim the reward tokens
    function claimReward() external updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            rewardsToken.transfer(msg.sender, reward);
        }
    }

    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }
}
