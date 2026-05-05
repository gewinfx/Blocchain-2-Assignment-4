// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract GovernanceToken is ERC20, ERC20Permit, ERC20Votes {
    
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


    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public
        view
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}