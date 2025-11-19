// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {AccessRegistry} from "../src/AccessRegistry.sol";
import {DistractionRecorder} from "../src/DistractionRecorder.sol";

/// @title Deploy
/// @notice Deployment script for AccessRegistry and DistractionRecorder contracts
/// @dev Supports mainnet, Sepolia, and Holesky networks
contract Deploy is Script {
    // Deployment addresses (will be set during deployment)
    AccessRegistry public accessRegistry;
    DistractionRecorder public distractionRecorder;

    function run() external {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_FORK");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("========================================");
        console.log("Starting Deployment");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("========================================");

        vm.startBroadcast(deployerPrivateKey);

        console.log("Contract Owner:", deployer);

        // Step 1: Deploy AccessRegistry
        console.log("\n[1/2] Deploying AccessRegistry...");
        accessRegistry = new AccessRegistry(deployer);
        console.log("AccessRegistry deployed at:", address(accessRegistry));

        // Step 2: Deploy DistractionRecorder
        console.log("\n[2/2] Deploying DistractionRecorder...");
        distractionRecorder = new DistractionRecorder(
            deployer,
            address(accessRegistry)
        );
        console.log(
            "DistractionRecorder deployed at:",
            address(distractionRecorder)
        );

        vm.stopBroadcast();

        // Summary
        console.log("\n========================================");
        console.log("Deployment Complete!");
        console.log("========================================");
        console.log("AccessRegistry:", address(accessRegistry));
        console.log("DistractionRecorder:", address(distractionRecorder));
        console.log("Owner:", deployer);
        console.log("========================================");

        // Verify deployment
        _verifyDeployment(deployer);
    }

    /// @notice Verify that contracts were deployed correctly
    function _verifyDeployment(address expectedOwner) internal view {
        console.log("\nVerifying deployment...");

        // Verify AccessRegistry
        require(
            address(accessRegistry) != address(0),
            "AccessRegistry not deployed"
        );
        require(
            accessRegistry.owner() == expectedOwner,
            "AccessRegistry owner mismatch"
        );
        console.log("AccessRegistry verification: PASSED");

        // Verify DistractionRecorder
        require(
            address(distractionRecorder) != address(0),
            "DistractionRecorder not deployed"
        );
        require(
            distractionRecorder.owner() == expectedOwner,
            "DistractionRecorder owner mismatch"
        );
        require(
            address(distractionRecorder.accessRegistry()) ==
                address(accessRegistry),
            "DistractionRecorder registry mismatch"
        );
        console.log("DistractionRecorder verification: PASSED");

        console.log("\nAll verifications passed!");
    }
}
