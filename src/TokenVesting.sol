// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title TokenVesting
 * @dev Контракт для линейной разблокировки токенов команды в течение 12 месяцев.
 */
contract TokenVesting {
    IERC20 public immutable token;
    address public immutable beneficiary;
    uint256 public immutable start;
    uint256 public immutable duration;
    uint256 public released;

    /**
     * @param _token Адрес развернутого GovernanceToken
     * @param _beneficiary Адрес кошелька команды
     */
    constructor(address _token, address _beneficiary) {
        require(_token != address(0), "Token address is zero");
        require(_beneficiary != address(0), "Beneficiary is zero");

        token = IERC20(_token);
        beneficiary = _beneficiary;
        start = block.timestamp;
        duration = 365 days; // Линейно в течение года
    }

    /**
     * @dev Переводит доступные разблокированные токены на адрес бенефициара.
     */
    function release() public {
        uint256 unreleased = vestedAmount() - released;
        require(unreleased > 0, "No tokens to release");

        released += unreleased;
        token.transfer(beneficiary, unreleased);
    }

    /**
     * @dev Высчитывает, сколько токенов разблокировано на текущий момент.
     */
    function vestedAmount() public view returns (uint256) {
        // Текущий баланс контракта + то, что уже вывели = общая сумма команды
        uint256 currentBalance = token.balanceOf(address(this));
        uint256 totalAllocated = currentBalance + released;

        if (block.timestamp < start) {
            return 0; 
        } else if (block.timestamp >= start + duration) {
            return totalAllocated; 
        } else {
            return (totalAllocated * (block.timestamp - start)) / duration;
        }
    }
}