// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.28;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';

abstract contract MockSwapRouter is ISwapRouter {
    // We'll store a value to return as `amountIn`
    uint256 public mockAmountIn;

    constructor(uint256 _mockAmountIn) {
        mockAmountIn = _mockAmountIn;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable override returns (uint256 amountOut) {
        return 0;
    }

    function exactInput(ExactInputParams calldata params) external payable override returns (uint256 amountOut) {
        return 0;
    }

    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable override returns (uint256 amountIn) {
        return mockAmountIn;
    }

    function exactOutput(ExactOutputParams calldata params) external payable override returns (uint256 amountIn) {
        return 0;
    }
}
