// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";
import "../src/TokenVesting.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken token;
    TokenVesting vesting;

    address teamBeneficiary = address(0x123);
    address treasury = address(0x456);
    address airdrop = address(0x789);
    address liquidity = address(0xABC);
    address user1 = address(0xDE1);
    address user2 = address(0xDE2);

    uint256 constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        token = new GovernanceToken(
            INITIAL_SUPPLY,
            address(this),
            treasury,
            airdrop,
            liquidity
        );

        vesting = new TokenVesting(address(token), teamBeneficiary);

        uint256 teamAmount = (INITIAL_SUPPLY * 40) / 100;
        token.transfer(address(vesting), teamAmount);
    }


    function test_InitialDistribution() public view {
        assertEq(token.balanceOf(address(vesting)), 400_000 ether, "Team 40% fail");
        assertEq(token.balanceOf(treasury), 300_000 ether, "Treasury 30% fail");
        assertEq(token.balanceOf(airdrop), 200_000 ether, "Airdrop 20% fail");
        assertEq(token.balanceOf(liquidity), 100_000 ether, "Liquidity 10% fail");
    }


    function test_Delegation() public {
        assertEq(token.getVotes(airdrop), 0);

        vm.prank(airdrop);
        token.delegate(airdrop);
        
        assertEq(token.getVotes(airdrop), 200_000 ether);
    }

    function test_VotingPowerSnapshots() public {
        vm.prank(airdrop);
        token.delegate(airdrop);
        
        uint256 blockNumber = block.number;
        vm.roll(block.number + 1); 

        assertEq(token.getPastVotes(airdrop, blockNumber), 200_000 ether);
    }

    function test_TransferUpdatesVotes() public {
        vm.prank(airdrop);
        token.delegate(airdrop);
        
        vm.prank(user1);
        token.delegate(user1);

        vm.prank(airdrop);
        token.transfer(user1, 50_000 ether);

        assertEq(token.getVotes(airdrop), 150_000 ether);
        assertEq(token.getVotes(user1), 50_000 ether);
    }


function test_PermitSignature() public {
    uint256 privateKey = 0xA11CE;
    address owner = vm.addr(privateKey);
    
    vm.prank(airdrop); 
    token.transfer(owner, 1000 ether);
    
    uint256 deadline = block.timestamp + 1 hours;
    
    bytes32 structHash = keccak256(abi.encode(
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
        owner,
        user1,
        100 ether,
        0,
        deadline
    ));
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash));
    
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

    token.permit(owner, user1, 100 ether, deadline, v, r, s);

    assertEq(token.allowance(owner, user1), 100 ether);
}

    function test_VestingScheduleMidway() public {
        vm.warp(block.timestamp + 182.5 days);
        
        uint256 expected = 200_000 ether;
        assertApproxEqAbs(vesting.vestedAmount(), expected, 0.1 ether);
    }

    function test_VestingFullRelease() public {
        vm.warp(block.timestamp + 365 days);
        
        vm.prank(teamBeneficiary);
        vesting.release();
        
        assertEq(token.balanceOf(teamBeneficiary), 400_000 ether);
        assertEq(token.balanceOf(address(vesting)), 0);
    }

    function test_VestingCannotReleaseEarly() public {
        vm.expectRevert("No tokens to release");
        vesting.release();
    }
}