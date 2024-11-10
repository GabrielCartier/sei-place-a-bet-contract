// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "@lib/seipex/IVRFConsumer.sol";
import {ERC20} from "@openzeppelin-contracts/token/ERC20/ERC20.sol";

struct MatchedBet {
    address player1;
    address player2;
    uint256 amount;
}

/**
 * @title Place a Bet
 * @dev A decentralized betting game where players can place bets (order of 10) to play against each other
 * @author Based on the original HeadToHead Contract by @0xQuit (https://apescan.io/address/0x88c1f4ecde714fba062853da1f686171f560ebaa)
 * @author @0xGabey
 */
contract PVP {
    error InvalidAmount();
    error NoMatchAvailable();
    error TransferFailed();

    // VRF Errors
    error InvalidVRFConsumer();
    error InvalidSignature();
    error InvalidProof();
    error InvalidRequestId();

    IVRFConsumer public constant VRF_CONSUMER = IVRFConsumer(0x7efDa6beA0e3cE66996FA3D82953FF232650ea67);

    // Maps bet amounts to pending players waiting for matches
    mapping(uint256 => address) public pendingBets;
    mapping(uint256 => MatchedBet) public matchedBets;

    event BetPlaced(address indexed player, uint256 amount);
    event BetMatched(address indexed player1, address indexed player2, uint256 amount);
    event BetResolved(address indexed winner, address indexed loser, uint256 amount);
    event BetCancelled(address indexed player, uint256 amount);

    ERC20 public constant CHIPS = ERC20(0xBd82f3bfE1dF0c84faEC88a22EbC34C9A86595dc);
    uint8 private immutable CHIPS_DECIMALS;
    uint256 private immutable BASE_UNIT;

    // Add constructor to set the immutable values
    constructor() {
        CHIPS_DECIMALS = CHIPS.decimals();
        BASE_UNIT = 10 ** CHIPS_DECIMALS;
    }

    function randomnessCallback(bytes32 randomNumber, uint256 requestId, bytes memory proof) external {
        // Ensure the caller is the VRFConsumer contract
        if (msg.sender != address(VRF_CONSUMER)) revert InvalidVRFConsumer();

        MatchedBet memory bet = matchedBets[requestId];
        address player1 = bet.player1;
        address player2 = bet.player2;
        uint256 betAmount = uint256(bet.amount);
        if (player1 == address(0)) revert InvalidRequestId();
        // Determine winner
        address winner = uint256(randomNumber) % 2 == 0 ? player1 : player2;
        address loser = winner == player1 ? player2 : player1;

        // transfer to winner
        if (!CHIPS.transfer(winner, betAmount * 2)) revert TransferFailed();
        emit BetResolved(winner, loser, betAmount);
    }

    function placeBet(uint256 amount) external {
        // Validate bet amount is a power of 10 based on CHIPS decimals
        if (amount == 0 || !_isPowerOfTen(amount)) revert InvalidAmount();

        // Place bet
        if (!CHIPS.transferFrom(msg.sender, address(this), amount)) revert TransferFailed();

        address opponent = pendingBets[amount];

        if (opponent == address(0)) {
            // No match available, store as pending
            pendingBets[amount] = msg.sender;
            emit BetPlaced(msg.sender, amount);
        } else {
            // Match found! Remove pending bet and play
            pendingBets[amount] = address(0);
            _playGame(opponent, amount);
        }
    }

    function _playGame(address opponent, uint256 amount) internal {
        bytes32 pseudoRandomNumber = keccak256(abi.encodePacked(block.timestamp, block.number, msg.sender));

        // pay the fees and request a random number from entropy
        uint256 requestId = VRF_CONSUMER.requestRandomness(pseudoRandomNumber);

        matchedBets[requestId] = MatchedBet(msg.sender, opponent, amount);
        emit BetMatched(msg.sender, opponent, amount);
    }

    function cancelBet(uint256 amount) external {
        if (pendingBets[amount] != msg.sender) revert NoMatchAvailable();

        pendingBets[amount] = address(0);
        // Transfer back the funds
        if (!CHIPS.transfer(msg.sender, amount)) revert TransferFailed();

        emit BetCancelled(msg.sender, amount);
    }

    // Helper function to check if amount is a power of 10 based on CHIPS decimals
    function _isPowerOfTen(uint256 amount) internal view returns (bool) {
        if (amount % BASE_UNIT != 0) return false;
        // Convert to whole token units for power of 10 check
        uint256 wholeTokens = amount / BASE_UNIT;

        // Add safety check for maximum reasonable bet
        if (wholeTokens > 1e9) return false; // Max 1 billion

        // If not 1, keep dividing by 10 and check remainder
        while (wholeTokens > 1) {
            if (wholeTokens % 10 != 0) return false;
            wholeTokens = wholeTokens / 10;
        }

        return wholeTokens == 1;
    }
}
