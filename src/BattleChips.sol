// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {IBattleChips} from "@battlechips/interfaces/IBattleChips.sol";
import {BattleChipsStorage} from "@battlechips/BattleChipsStorage.sol";
import {IEntropy} from "@pythnetwork/IEntropy.sol";
import {IEntropyConsumer} from "@pythnetwork/IEntropyConsumer.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

contract BattleChips is IBattleChips, BattleChipsStorage, Ownable, IEntropyConsumer {
    uint256 private constant TAX_RATE = 250; // 2.5%
    uint256 private constant BASIS_POINTS = 10000; // 100%

    address private constant MULTISIG = 0xBDc6dDF7D37F8FeC261DEdC44A470B42CB9ffDb0;
    IEntropy public constant ENTROPY = IEntropy(0x98046Bd286715D3B0BC227Dd7a956b83D8978603);
    address public constant PROVIDER = 0x52DeaA1c84233F7bb8C8A45baeDE41091c616506;

    constructor() {
        _initializeOwner(msg.sender);
    }

    // @dev For IEntropyConsumer
    function getEntropy() internal view override returns (address) {
        return address(ENTROPY);
    }

    function addToken(address token) external onlyOwner {
        allowedTokens[token] = true;
        emit TokenAdded(token);
    }

    function removeToken(address token) external onlyOwner {
        allowedTokens[token] = false;
        emit TokenRemoved(token);
    }

    function placeBet(address token, uint256 amount) external payable {
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

    function entropyCallback(uint64 sequenceNumber, address, bytes32 randomNumber) internal override {
        // @dev We dont do a check on the provider address as a fail-safe

        MatchedBet memory bet = matchedBets[sequenceNumber];
        if (bet.player1 == address(0)) revert InvalidSequenceNumber();
        delete matchedBets[sequenceNumber];

        address winner = uint256(randomNumber) % 2 == 0 ? bet.player1 : bet.player2;
        address loser = winner == bet.player1 ? bet.player2 : bet.player1;

        uint256 totalPrize = bet.amount * 2;
        uint256 tax = (totalPrize * TAX_RATE) / BASIS_POINTS;
        uint256 winnerPrize = totalPrize - tax;

        accumulatedFees[bet.token] += tax;
        if (!ERC20(bet.token).transfer(winner, winnerPrize)) revert TransferFailed();

        emit BetResolved(bet.token, winner, loser, bet.amount, sequenceNumber);
    }

    function _playGame(address token, address opponent, uint256 amount) internal {
        // @dev Get the request fee for the provider
        uint128 requestFee = ENTROPY.getFee(PROVIDER);

        if (msg.value < requestFee) revert InsufficientFunds();

        bytes32 pseudoRandomNumber = keccak256(abi.encodePacked(block.timestamp, block.number, msg.sender));
        uint64 sequenceNumber = ENTROPY.requestWithCallback{value: requestFee}(PROVIDER, pseudoRandomNumber);

        matchedBets[sequenceNumber] = MatchedBet(token, msg.sender, opponent, amount);
        emit BetMatched(token, msg.sender, opponent, amount, sequenceNumber, pseudoRandomNumber);
    }

    function withdrawFees(address token) external {
        uint256 amount = accumulatedFees[token];
        if (amount == 0) revert NoFeesToWithdraw();

        accumulatedFees[token] = 0;

        if (!ERC20(token).transfer(MULTISIG, amount)) revert TransferFailed();

        emit FeesWithdrawn(token, amount);
    }
}
