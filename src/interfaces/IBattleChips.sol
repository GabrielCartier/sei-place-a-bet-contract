// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IBattleChips {
    // Errors
    error InvalidAmount();
    error NoMatchAvailable();
    error TransferFailed();
    error RequestNotExpired();
    error TokenNotAllowed();
    error InvalidSequenceNumber();
    error NoFeesToWithdraw();
    error InsufficientFunds();
    // Events

    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event BetPlaced(address indexed token, address indexed player, uint256 amount);
    event BetMatched(address indexed token, address indexed player1, address indexed player2, uint256 amount);
    event BetResolved(address indexed token, address indexed winner, address indexed loser, uint256 amount);
    event BetCancelled(address indexed token, address indexed player, uint256 amount);
    event FeesWithdrawn(address indexed token, uint256 amount);

    // Functions
    function addToken(address token) external;
    function removeToken(address token) external;
    function placeBet(address token, uint256 amount) external payable;
    function cancelBet(address token, uint256 amount) external;
    function withdrawFees(address token) external;
}
