// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "@lib/seipex/IVRFConsumer.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {IBattleChips} from "@battlechips/interfaces/IBattleChips.sol";
import {BattleChipsStorage} from "@battlechips/BattleChipsStorage.sol";

contract BattleChips is IBattleChips, BattleChipsStorage, Ownable {
    uint256 private constant TAX_RATE = 420; // 4.20%
    uint256 private constant BASIS_POINTS = 10000; // 100%

    address private constant MULTISIG = 0xBDc6dDF7D37F8FeC261DEdC44A470B42CB9ffDb0;
    IVRFConsumer private constant VRF_CONSUMER = IVRFConsumer(0x7efDa6beA0e3cE66996FA3D82953FF232650ea67);

    constructor() {
        _initializeOwner(msg.sender);
    }

    function addToken(address token) external onlyOwner {
        allowedTokens[token] = true;
        emit TokenAdded(token);
    }

    function removeToken(address token) external onlyOwner {
        allowedTokens[token] = false;
        emit TokenRemoved(token);
    }

    function placeBet(address token, uint256 amount) external {
        if (!allowedTokens[token]) revert TokenNotAllowed();

        if (!ERC20(token).transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        address opponent = pendingBets[token][amount];

        if (opponent == address(0)) {
            pendingBets[token][amount] = msg.sender;
            emit BetPlaced(token, msg.sender, amount);
        } else {
            pendingBets[token][amount] = address(0);
            _playGame(token, opponent, amount);
        }
    }

    function cancelBet(address token, uint256 amount) external {
        if (pendingBets[token][amount] != msg.sender) revert NoMatchAvailable();

        pendingBets[token][amount] = address(0);
        if (!ERC20(token).transfer(msg.sender, amount)) revert TransferFailed();

        emit BetCancelled(token, msg.sender, amount);
    }

    function randomnessCallback(bytes32 randomNumber, uint256 requestId, bytes memory /* proof */ ) external {
        if (msg.sender != address(VRF_CONSUMER)) revert InvalidVRFConsumer();

        MatchedBet memory bet = matchedBets[requestId];
        if (bet.player1 == address(0)) revert InvalidRequestId();
        delete matchedBets[requestId];

        address winner = uint256(randomNumber) % 2 == 0 ? bet.player1 : bet.player2;
        address loser = winner == bet.player1 ? bet.player2 : bet.player1;

        uint256 totalPrize = bet.amount * 2;
        uint256 tax = (totalPrize * TAX_RATE) / BASIS_POINTS;
        uint256 winnerPrize = totalPrize - tax;

        accumulatedFees[bet.token] += tax;

        if (!ERC20(bet.token).transfer(winner, winnerPrize)) revert TransferFailed();

        emit BetResolved(bet.token, winner, loser, bet.amount);
    }

    function redeemExpiredBet(address token, uint256 requestId) external {
        MatchedBet memory bet = matchedBets[requestId];
        if (bet.player1 == address(0) || bet.player2 == address(0)) revert InvalidRequestId();
        if (bet.token != token) revert InvalidRequestId();

        RandomnessRequest memory request = VRF_CONSUMER.getRequestById(requestId);
        if (request.status != 2) revert RequestNotExpired();

        delete matchedBets[requestId];

        if (!ERC20(token).transfer(bet.player1, bet.amount)) revert TransferFailed();
        if (!ERC20(token).transfer(bet.player2, bet.amount)) revert TransferFailed();

        emit BetCancelled(token, bet.player1, bet.amount);
        emit BetCancelled(token, bet.player2, bet.amount);
    }

    function _playGame(address token, address opponent, uint256 amount) internal {
        bytes32 pseudoRandomNumber = keccak256(abi.encodePacked(block.timestamp, block.number, msg.sender));
        uint256 requestId = VRF_CONSUMER.requestRandomness(pseudoRandomNumber);

        matchedBets[requestId] = MatchedBet(token, msg.sender, opponent, amount);
        emit BetMatched(token, msg.sender, opponent, amount);
    }

    function withdrawFees(address token) external {
        uint256 amount = accumulatedFees[token];
        if (amount == 0) revert NoFeesToWithdraw();

        accumulatedFees[token] = 0;

        if (!ERC20(token).transfer(MULTISIG, amount)) revert TransferFailed();

        emit FeesWithdrawn(token, amount);
    }
}
