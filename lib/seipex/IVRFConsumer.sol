// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IVRFConsumer {
    function requestRandomness(bytes32 userProvidedSeed) external returns (uint256);
    function getRequestById(uint256 nonce) external view returns (RandomnessRequest memory);
    function getVRFPublicKey() external view returns (address);
}

struct RandomnessRequest {
    address requester;
    uint256 requestBlock;
    uint256 requestId;
    bytes32 userProvidedSeed;
    uint8 status;
    bytes32 randomNumber;
    bytes32 proof;
}
