// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/GovernanceToken.sol";
import "../src/Treasury.sol";
import "../src/MyGovernor.sol";
import "../src/Box.sol";

contract DeployFinal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);

        uint256 initialSupply = 1000000 * 10**18;
        
        GovernanceToken token = new GovernanceToken(
            initialSupply,
            deployerAddress,
            deployerAddress,
            deployerAddress,
            deployerAddress
        );

        uint256 minDelay = 172800; 
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        
        Treasury timelock = new Treasury(minDelay, proposers, executors, deployerAddress);

        MyGovernor governor = new MyGovernor(token, timelock);

        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        bytes32 ADMIN_ROLE = 0x00; 

        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(EXECUTOR_ROLE, address(0));
        timelock.revokeRole(ADMIN_ROLE, deployerAddress);

        Box box = new Box();
        box.transferOwnership(address(timelock));

        vm.stopBroadcast();
        
        console.log("GovernanceToken deployed at:", address(token));
        console.log("Governor deployed at:", address(governor));
        console.log("Timelock (Treasury) deployed at:", address(timelock));
        console.log("Box deployed at:", address(box));
    }
}