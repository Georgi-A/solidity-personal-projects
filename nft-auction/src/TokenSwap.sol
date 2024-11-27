// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.28;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

library TokenSwap {
    // ISwapRouter public immutable swapRouter;

    // constructor(ISwapRouter _swapRouter) {
    //     swapRouter = _swapRouter;
    // }

    // function swapExactOutputSingle(address tokenIn, address tokenOut, uint256 amountOut, uint256 amountInMaximum) external returns (uint256 amountIn) {
    //     // Transfer the specified amount of DAI to this contract.
    //     TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountInMaximum);

    //     // Approve the router to spend the specifed `amountInMaximum` of DAI.
    //     // In production, you should choose the maximum amount to spend based on oracles or other data sources to acheive a better swap.
    //     TransferHelper.safeApprove(tokenIn, address(swapRouter), amountInMaximum);

    //     ISwapRouter.ExactOutputSingleParams memory params =
    //         ISwapRouter.ExactOutputSingleParams({
    //             tokenIn: tokenIn,
    //             tokenOut: tokenOut,
    //             fee: poolFee,
    //             recipient: msg.sender,
    //             deadline: block.timestamp,
    //             amountOut: amountOut,
    //             amountInMaximum: amountInMaximum,
    //             sqrtPriceLimitX96: 0
    //         });

    //     // Executes the swap returning the amountIn needed to spend to receive the desired amountOut.
    //     amountIn = swapRouter.exactOutputSingle(params);

    //     // For exact output swaps, the amountInMaximum may not have all been spent.
    //     // If the actual amount spent (amountIn) is less than the specified maximum amount, we must refund the msg.sender and approve the swapRouter to spend 0.
    //     if (amountIn < amountInMaximum) {
    //         TransferHelper.safeApprove(tokenIn, address(swapRouter), 0);
    //         TransferHelper.safeTransfer(tokenIn, msg.sender, amountInMaximum - amountIn);
    //     }
    // }
}
