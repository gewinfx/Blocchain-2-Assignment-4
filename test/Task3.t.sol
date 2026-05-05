// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";
import "../src/MyGovernor.sol";
import "../src/Treasury.sol";
import "../src/Box.sol";

contract Task3Test is Test {
    GovernanceToken token;
    MyGovernor governor;
    Treasury treasury;
    Box box;

    address voter = address(100);

    function setUp() public {
        token = new GovernanceToken(1_000_000 ether, address(this), address(this), address(this), address(this));
        token.transfer(voter, 100_000 ether);
        vm.prank(voter);
        token.delegate(voter);

        address[] memory empty;
        treasury = new Treasury(2 days, empty, empty, address(this));
        
        governor = new MyGovernor(token, treasury);
        
        treasury.grantRole(treasury.PROPOSER_ROLE(), address(governor));
        treasury.grantRole(treasury.EXECUTOR_ROLE(), address(0));

        box = new Box();
        box.transferOwnership(address(treasury));
        
        vm.roll(block.number + 1);
    }

    function test_Governance_Store42() public {
        bytes memory data = abi.encodeWithSelector(box.store.selector, 42);
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(box);
        values[0] = 0;
        calldatas[0] = data;
        
        string memory description = "Proposal: Store 42 in Box";

        vm.prank(voter);
        uint256 id = governor.propose(targets, values, calldatas, description);
        console.log("Step 1: Proposal created with ID:", id);

        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(voter);
        governor.castVote(id, 1); // 1 = For
        console.log("Step 2: Vote casted 'For'");

        vm.roll(block.number + governor.votingPeriod() + 1);
        governor.queue(targets, values, calldatas, keccak256(bytes(description)));
        console.log("Step 3: Proposal queued in Timelock");

        vm.warp(block.timestamp + 2 days + 1);
        governor.execute(targets, values, calldatas, keccak256(bytes(description)));
        console.log("Step 4: Proposal executed");

        assertEq(box.retrieve(), 42);
        console.log("Step 5: Verification successful. Value in Box is 42");
    }
}