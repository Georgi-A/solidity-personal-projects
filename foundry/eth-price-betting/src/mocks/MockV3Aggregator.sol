// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MockV3Aggregator {
    int256 private answer;

    constructor(int256 _initialAnswer) {
        answer = _initialAnswer;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundID,
            int256 answer_,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (0, answer, 0, 0, 0);
    }

    function setAnswer(int256 _answer) external {
        answer = _answer * 10 ** 8;
    }

    function getAnswer() external view returns (int256) {
        return answer / 10 ** 8;
    }
}
