// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Импортируем стандарты OpenZeppelin
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

/**
 * @title GovernanceToken
 * @dev Токен управления с поддержкой делегирования (Votes) и безгазовых аппрувов (Permit)
 */
contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes {
    
    /**
     * @param initialSupply Общее количество токенов (например, 1 000 000 * 10**18)
     * @param teamVesting Адрес контракта TokenVesting.sol
     * @param treasury Адрес казначейства DAO
     * @param communityAirdrop Адрес для распределения аирдропа
     * @param liquidity Адрес для обеспечения ликвидности (DEX)
     */
    constructor(
        uint256 initialSupply,
        address teamVesting,
        address treasury,
        address communityAirdrop,
        address liquidity
    ) 
        ERC20("Governance Token", "GTK") 
        ERC20Permit("Governance Token") 
    {
        
        _mint(teamVesting, (initialSupply * 40) / 100);
        
        _mint(treasury, (initialSupply * 30) / 100);
        
        _mint(communityAirdrop, (initialSupply * 20) / 100);
        
        _mint(liquidity, (initialSupply * 10) / 100);
    }


    /**
     * @dev Функция _update вызывается при любых переводах токенов.
     * Она обновляет балансы и веса голосов.
     */
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    /**
     * @dev Возвращает текущий порядковый номер подписи (nonce) для EIP-712 (Permit).
     */
    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}