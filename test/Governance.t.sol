// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";
import "../src/MyGovernor.sol";
import "../src/Xyz.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovernanceTest is Test {
    GovernanceToken token;
    MyGovernor governor;
    TimelockController timelock;
    Xyz box;

    address public proposer = address(1);
    address public voter1 = address(2);
    address public voter2 = address(3);
    address[] proposers;
    address[] executors;

    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;

    function setUp() public {
        token = new GovernanceToken(INITIAL_SUPPLY, address(this), address(0x456), address(0x789), address(0xABC));
        
        proposers = new address[](0);
        executors = new address[](0);
        timelock = new TimelockController(2 days, proposers, executors, address(this));

        governor = new MyGovernor(token, timelock);

        // Настройка ролей
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0)); 
        timelock.revokeRole(adminRole, address(this)); 

        box = new Xyz();
        box.transferOwnership(address(timelock));

        token.transfer(proposer, 11_000 ether); 
        token.transfer(voter1, 50_000 ether);  
        
        vm.prank(proposer);
        token.delegate(proposer);
        vm.prank(voter1);
        token.delegate(voter1);
        
        vm.roll(block.number + 1); 
    }

    function test_FullGovernanceLifecycle() public {
        string memory description = "Set fee to 10";
        bytes memory data = abi.encodeWithSelector(box.setFee.selector, 10);
        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(box);
        values[0] = 0;
        calldatas[0] = data;

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(voter1);
        governor.castVote(proposalId, 1); 

        vm.roll(block.number + governor.votingPeriod() + 1);

        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + 2 days + 1);

        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(box.feePercentage(), 10);
    }

    function test_Fail_BelowThreshold() public {
        address poorUser = address(9);
        token.transfer(poorUser, 100 ether); // < 1%
        vm.prank(poorUser);
        token.delegate(poorUser);
        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = address(box);

        vm.prank(poorUser);
        vm.expectRevert(); 
        governor.propose(targets, values, calldatas, "Low supply proposal");
    }

    function test_Fail_NoQuorum() public {
        _createProposal();
        vm.roll(block.number + governor.votingDelay() + governor.votingPeriod() + 1);
        
        vm.expectRevert();
        governor.queue(_getTargets(), _getValues(), _getCalldatas(), keccak256(bytes("Test")));
    }

    function test_TreasuryTransferProposal() public {
        token.transfer(address(timelock), 1000 ether); 
        
        bytes memory data = abi.encodeWithSelector(token.transfer.selector, voter2, 500 ether);
        _executeSuccessfulProposal(address(token), data, "Pay voter2");
        
        assertEq(token.balanceOf(voter2), 500 ether);
    }

    function test_DelegationImpact() public {
        address delegator = address(55);
        token.transfer(delegator, 100_000 ether);
        
        assertEq(governor.getVotes(voter2, block.number - 1), 0);
        
        vm.prank(delegator);
        token.delegate(voter2);
        vm.roll(block.number + 1);
        
        assertEq(governor.getVotes(voter2, block.number - 1), 100_000 ether);
    }

    function test_Fail_EarlyExecution() public {
        _createProposalAndVote();
        governor.queue(_getTargets(), _getValues(), _getCalldatas(), keccak256(bytes("Test")));
        
        vm.expectRevert(); 
        governor.execute(_getTargets(), _getValues(), _getCalldatas(), keccak256(bytes("Test")));
    }

    function test_OnlyTimelockCanSetFee() public {
        vm.expectRevert();
        box.setFee(99); 
    }

    function test_ProposalDefeated() public {
        uint256 proposalId = _createProposal();
        vm.roll(block.number + governor.votingDelay() + 1);
        governor.castVote(proposalId, 0); // 0 = Against
        vm.roll(block.number + governor.votingPeriod() + 1);
        
        assertEq(uint(governor.state(proposalId)), 3); 
    }

    function test_CancelProposal() public {
        vm.prank(proposer);
        uint256 proposalId = governor.propose(_getTargets(), _getValues(), _getCalldatas(), "Cancel me");
        
        vm.prank(proposer);
        governor.cancel(_getTargets(), _getValues(), _getCalldatas(), keccak256(bytes("Cancel me")));
        
        assertEq(uint(governor.state(proposalId)), 2); 
    }

    function test_Fail_VoteTooEarly() public {
        uint256 proposalId = _createProposal();
        vm.expectRevert();
        governor.castVote(proposalId, 1);
    }

    function test_Fail_QueueTooEarly() public {
        uint256 proposalId = _createProposal();
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(voter1);
        governor.castVote(proposalId, 1);
        
        vm.expectRevert(); 
        governor.queue(_getTargets(), _getValues(), _getCalldatas(), keccak256(bytes("Test")));
    }

    function test_Fail_ReexecuteProposal() public {
        test_FullGovernanceLifecycle(); 
        vm.expectRevert();
        governor.execute(_getTargets(), _getValues(), _getCalldatas(), keccak256(bytes("Set fee to 10")));
    }

    function _createProposal() internal returns (uint256) {
        vm.prank(proposer);
        return governor.propose(_getTargets(), _getValues(), _getCalldatas(), "Test");
    }

    function _createProposalAndVote() internal returns (uint256) {
        uint256 id = _createProposal();
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(voter1);
        governor.castVote(id, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);
        return id;
    }

    function _executeSuccessfulProposal(address target, bytes memory data, string memory desc) internal {
        address[] memory targets = new address[](1);
        targets[0] = target;
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = data;

        vm.prank(proposer);
        uint256 id = governor.propose(targets, values, calldatas, desc);
        vm.roll(block.number + governor.votingDelay() + 1);
        vm.prank(voter1);
        governor.castVote(id, 1);
        vm.roll(block.number + governor.votingPeriod() + 1);
        governor.queue(targets, values, calldatas, keccak256(bytes(desc)));
        vm.warp(block.timestamp + 2 days + 1);
        governor.execute(targets, values, calldatas, keccak256(bytes(desc)));
    }

    function _getTargets() internal view returns (address[] memory) {
        address[] memory t = new address[](1);
        t[0] = address(box);
        return t;
    }

    function _getValues() internal pure returns (uint256[] memory) {
        uint256[] memory v = new uint256[](1);
        v[0] = 0;
        return v;
    }

    function _getCalldatas() internal view returns (bytes[] memory) {
        bytes[] memory c = new bytes[](1);
        c[0] = abi.encodeWithSelector(box.setFee.selector, 10);
        return c;
    }
}