// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Xyz is Ownable {
    uint256 public feePercentage;

    event FeeChanged(uint256 newValue);

    constructor() Ownable(msg.sender) {}

    function setFee(uint256 newValue) external onlyOwner {
        feePercentage = newValue;
        emit FeeChanged(newValue);
    }

    function getFee() external view returns (uint256) {
        return feePercentage;
    }
}