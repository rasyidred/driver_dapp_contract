// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {AccessRegistry} from "../src/AccessRegistry.sol";
import {DistractionRecorder} from "../src/DistractionRecorder.sol";

/// @title DeploySepolia
/// @notice Deployment script for Sepolia Testnet
contract DeploySepolia is Script {
    AccessRegistry public accessRegistry;
    DistractionRecorder public distractionRecorder;

    function run() external {
        // Load Sepolia private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_SEPOLIA");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("========================================");
        console.log("Deploying to SEPOLIA TESTNET");
        console.log("========================================");
        console.log("Deployer Address:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("========================================");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy AccessRegistry
        console.log("\n[1/2] Deploying AccessRegistry...");
        accessRegistry = new AccessRegistry(deployer);
        console.log("AccessRegistry deployed at:", address(accessRegistry));

        // Deploy DistractionRecorder
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
        console.log("SEPOLIA DEPLOYMENT COMPLETE");
        console.log("========================================");
        console.log("Network: Sepolia Testnet");
        console.log("Chain ID:", block.chainid);
        console.log("AccessRegistry:", address(accessRegistry));
        console.log("DistractionRecorder:", address(distractionRecorder));
        console.log("Owner:", deployer);
        console.log("========================================");
        console.log("\nSave these addresses for verification:");
        console.log(
            "export ACCESS_REGISTRY_SEPOLIA=",
            vm.toString(address(accessRegistry))
        );
        console.log(
            "export DISTRACTION_RECORDER_SEPOLIA=",
            vm.toString(address(distractionRecorder))
        );
        console.log("========================================");
    }
}
