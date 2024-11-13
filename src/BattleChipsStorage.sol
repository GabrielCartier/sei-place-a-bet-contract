// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

contract BattleChipsStorage {
    struct MatchedBet {
        address token;
        address player1;
        address player2;
        uint256 amount;
    }

    struct PendingBet {
        address token;
        address player;
    }

    // Maps token => amount => player address
    mapping(address => mapping(uint256 => address)) public pendingBets;

    // Maps requestId => matched bet details
    mapping(uint256 => MatchedBet) public matchedBets;

    // Allowed tokens
    mapping(address => bool) public allowedTokens;

    // Accumulated fees per token
    mapping(address => uint256) public accumulatedFees;
}
