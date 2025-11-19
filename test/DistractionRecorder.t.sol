// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {DistractionRecorder} from "../src/DistractionRecorder.sol";
import {AccessRegistry} from "../src/AccessRegistry.sol";
import {IAccessRegistry} from "../src/interfaces/IAccessRegistry.sol";

contract DistractionRecorderTest is Test {
    DistractionRecorder public recorder;
    AccessRegistry public registry;

    // Test accounts
    address public owner;
    address public driver1;
    address public driver2;
    address public stakeholder1;
    address public stakeholder2;
    address public stakeholder3;
    address public nonStakeholder;

    // Events to test
    event StakeholderBlacklisted(
        address indexed driver,
        address indexed stakeholder
    );
    event BlacklistRemoved(address indexed driver, address indexed stakeholder);
    event DistractedDrivingRecorded(
        address indexed driver,
        string indexed vehicleNumber,
        DistractionRecorder.EventClass indexed eventClass,
        uint256 timestamp,
        uint256 recordId
    );

    function setUp() public {
        // Create test accounts
        owner = makeAddr("owner");
        driver1 = makeAddr("driver1");
        driver2 = makeAddr("driver2");
        stakeholder1 = makeAddr("stakeholder1");
        stakeholder2 = makeAddr("stakeholder2");
        stakeholder3 = makeAddr("stakeholder3");
        nonStakeholder = makeAddr("nonStakeholder");

        // Deploy contracts
        vm.startPrank(owner);
        registry = new AccessRegistry(owner);
        recorder = new DistractionRecorder(owner, address(registry));

        // Register stakeholders with different roles
        registry.registerStakeholder(
            stakeholder1,
            IAccessRegistry.StakeholderRole.Police
        );
        registry.registerStakeholder(
            stakeholder2,
            IAccessRegistry.StakeholderRole.InsuranceCompany
        );
        registry.registerStakeholder(
            stakeholder3,
            IAccessRegistry.StakeholderRole.LogisticsCompany
        );

        // Setup vehicle numbers for drivers
        registry.updateVehicleForDriver(driver1, "ABC123");
        registry.updateVehicleForDriver(driver2, "XYZ789");
        vm.stopPrank();

        // Drivers authorize stakeholders
        vm.startPrank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);
        registry.addAuthorizedStakeholder(stakeholder2);
        vm.stopPrank();

        vm.startPrank(driver2);
        registry.addAuthorizedStakeholder(stakeholder1);
        registry.addAuthorizedStakeholder(stakeholder3);
        vm.stopPrank();
    }

    // ============================================
    // CATEGORY 1: Blacklist Management Tests
    // ============================================

    function test_DriverCanBlacklistStakeholder() public {
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        assertTrue(recorder.blacklist(driver1, stakeholder1));
    }

    function test_DriverCanRemoveStakeholderFromBlacklist() public {
        // First blacklist
        vm.startPrank(driver1);
        recorder.blacklistStakeholder(stakeholder1);
        assertTrue(recorder.blacklist(driver1, stakeholder1));

        // Then remove
        recorder.removeFromBlacklist(stakeholder1);
        assertFalse(recorder.blacklist(driver1, stakeholder1));
        vm.stopPrank();
    }

    function test_CannotBlacklistZeroAddress() public {
        vm.prank(driver1);
        vm.expectRevert(DistractionRecorder.ZeroAddress.selector);
        recorder.blacklistStakeholder(address(0));
    }

    function test_CannotRemoveZeroAddressFromBlacklist() public {
        vm.prank(driver1);
        vm.expectRevert(DistractionRecorder.ZeroAddress.selector);
        recorder.removeFromBlacklist(address(0));
    }

    function test_IsBlacklistedReturnsCorrectStatus() public {
        // Initially not blacklisted
        assertFalse(recorder.isBlacklisted(driver1, stakeholder1));

        // After blacklisting
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);
        assertTrue(recorder.isBlacklisted(driver1, stakeholder1));

        // After removal
        vm.prank(driver1);
        recorder.removeFromBlacklist(stakeholder1);
        assertFalse(recorder.isBlacklisted(driver1, stakeholder1));
    }

    function test_BlacklistMappingPersistsCorrectly() public {
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Direct mapping check
        bool isBlacklisted = recorder.blacklist(driver1, stakeholder1);
        assertTrue(isBlacklisted);

        // View function check
        assertTrue(recorder.isBlacklisted(driver1, stakeholder1));
    }

    // ============================================
    // CATEGORY 2: Access Control via Modifier Tests
    // ============================================

    function test_BeforeAndAfterBlacklisting_AccessControlChanges() public {
        // Driver records events
        vm.startPrank(driver1);
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventPhoneRight();
        recorder.recordDistractionEventDrinking();
        vm.stopPrank();

        // BEFORE BLACKLISTING: Stakeholder1 can access records
        vm.prank(stakeholder1);
        (
            string[] memory vehicleNumbers,
            DistractionRecorder.EventClass[] memory eventClasses,
            uint256[] memory timestamps
        ) = recorder.getDriverRecords(driver1);
        assertEq(timestamps.length, 3);
        assertEq(
            uint256(eventClasses[0]),
            uint256(DistractionRecorder.EventClass.TextingRight)
        );
        assertEq(
            uint256(eventClasses[1]),
            uint256(DistractionRecorder.EventClass.PhoneRight)
        );
        assertEq(
            uint256(eventClasses[2]),
            uint256(DistractionRecorder.EventClass.Drinking)
        );

        // Verify stakeholder1 is not blacklisted yet
        assertFalse(recorder.isBlacklisted(driver1, stakeholder1));

        // Driver blacklists stakeholder1
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Verify stakeholder1 is now blacklisted
        assertTrue(recorder.isBlacklisted(driver1, stakeholder1));

        // AFTER BLACKLISTING: Stakeholder1 CANNOT access records
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);

        // Driver records another event
        vm.prank(driver1);
        recorder.recordDistractionEventHairMakeup();

        // Stakeholder1 still CANNOT access (even with new records)
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);

        // BUT stakeholder2 (not blacklisted, authorized) CAN still access
        vm.prank(stakeholder2);
        (
            string[] memory vehicleNumbers2,
            DistractionRecorder.EventClass[] memory eventClasses2,
            uint256[] memory timestamps2
        ) = recorder.getDriverRecords(driver1);
        assertEq(timestamps2.length, 4);
    }

    function test_BlacklistedStakeholderCannotAccessRecords() public {
        // Driver records an event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Driver blacklists stakeholder1
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Stakeholder1 tries to access records (should fail)
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);
    }

    function test_NonBlacklistedStakeholderCanAccessRecords() public {
        // Driver records an event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Stakeholder1 (authorized, not blacklisted) accesses records
        vm.prank(stakeholder1);
        (
            string[] memory vehicleNumbers,
            DistractionRecorder.EventClass[] memory eventClasses,
            uint256[] memory timestamps
        ) = recorder.getDriverRecords(driver1);

        assertEq(timestamps.length, 1);
        assertEq(
            uint256(eventClasses[0]),
            uint256(DistractionRecorder.EventClass.TextingRight)
        );
    }

    function test_RemovingFromBlacklistRestoresAccess() public {
        // Driver records an event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Driver blacklists stakeholder1
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Stakeholder1 cannot access
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);

        // Driver removes from blacklist
        vm.prank(driver1);
        recorder.removeFromBlacklist(stakeholder1);

        // Stakeholder1 can now access
        vm.prank(stakeholder1);
        (
            string[] memory vehicleNumbers,
            DistractionRecorder.EventClass[] memory eventClasses,
            uint256[] memory timestamps
        ) = recorder.getDriverRecords(driver1);
        assertEq(timestamps.length, 1);
    }

    function test_BlacklistCheckHappensPriorToAuthorizationCheck() public {
        // Driver blacklists non-registered stakeholder
        vm.prank(driver1);
        recorder.blacklistStakeholder(nonStakeholder);

        // Non-stakeholder tries to access (should fail with BlacklistedStakeholder, not UnauthorizedStakeholder)
        vm.prank(nonStakeholder);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);
    }

    // ============================================
    // CATEGORY 3: Multi-Driver Independence Tests
    // ============================================

    function test_BlacklistIsDriverSpecific() public {
        // Both drivers record events
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();
        vm.prank(driver2);
        recorder.recordDistractionEventPhoneRight();

        // Driver1 blacklists stakeholder1
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Stakeholder1 cannot access driver1 records
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);

        // But stakeholder1 CAN access driver2 records (authorized and not blacklisted by driver2)
        vm.prank(stakeholder1);
        (, , uint256[] memory timestamps) = recorder.getDriverRecords(driver2);
        assertEq(timestamps.length, 1);
    }

    function test_EachDriverManagesTheirOwnBlacklist() public {
        // Both drivers blacklist the same stakeholder
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        vm.prank(driver2);
        recorder.blacklistStakeholder(stakeholder1);

        // Verify independent blacklists
        assertTrue(recorder.isBlacklisted(driver1, stakeholder1));
        assertTrue(recorder.isBlacklisted(driver2, stakeholder1));

        // Driver1 removes from blacklist
        vm.prank(driver1);
        recorder.removeFromBlacklist(stakeholder1);

        // Driver1's blacklist updated, driver2's unchanged
        assertFalse(recorder.isBlacklisted(driver1, stakeholder1));
        assertTrue(recorder.isBlacklisted(driver2, stakeholder1));
    }

    function test_MultipleStakeholdersBlacklistedIndependently() public {
        // Driver blacklists multiple stakeholders
        vm.startPrank(driver1);
        recorder.blacklistStakeholder(stakeholder1);
        recorder.blacklistStakeholder(stakeholder2);
        recorder.blacklistStakeholder(stakeholder3);
        vm.stopPrank();

        // Verify all blacklisted
        assertTrue(recorder.isBlacklisted(driver1, stakeholder1));
        assertTrue(recorder.isBlacklisted(driver1, stakeholder2));
        assertTrue(recorder.isBlacklisted(driver1, stakeholder3));

        // Remove stakeholder2
        vm.prank(driver1);
        recorder.removeFromBlacklist(stakeholder2);

        // Verify stakeholder2 removed, others remain
        assertTrue(recorder.isBlacklisted(driver1, stakeholder1));
        assertFalse(recorder.isBlacklisted(driver1, stakeholder2));
        assertTrue(recorder.isBlacklisted(driver1, stakeholder3));
    }

    // ============================================
    // CATEGORY 4: Integration Tests
    // ============================================

    function test_BlacklistingDoesNotAffectDriverRecordingEvents() public {
        // Driver blacklists a stakeholder
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Driver can still record events
        vm.prank(driver1);
        uint256 recordId = recorder.recordDistractionEventTextingRight();

        assertEq(recordId, 0);
        assertEq(recorder.driverRecordCounts(driver1), 1);
    }

    function test_AuthorizationStillRequiredWithoutBlacklist() public {
        // Driver records an event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // stakeholder3 is registered but NOT authorized by driver1
        vm.prank(stakeholder3);
        vm.expectRevert(DistractionRecorder.AccessBlocked.selector);
        recorder.getDriverRecords(driver1);
    }

    function test_ConstructorRejectsZeroRegistryAddress() public {
        // Constructor should revert if registry address is zero
        vm.prank(owner);
        vm.expectRevert(DistractionRecorder.ZeroAddress.selector);
        new DistractionRecorder(owner, address(0));
    }

    // ============================================
    // CATEGORY 5: Edge Cases Tests
    // ============================================

    function test_BlacklistingAlreadyBlacklistedStakeholder() public {
        vm.startPrank(driver1);

        // First blacklist
        recorder.blacklistStakeholder(stakeholder1);
        assertTrue(recorder.isBlacklisted(driver1, stakeholder1));

        // Blacklist again (should not revert, idempotent)
        recorder.blacklistStakeholder(stakeholder1);
        assertTrue(recorder.isBlacklisted(driver1, stakeholder1));

        vm.stopPrank();
    }

    function test_RemovingNonBlacklistedStakeholder() public {
        // Stakeholder never blacklisted
        assertFalse(recorder.isBlacklisted(driver1, stakeholder1));

        // Remove from blacklist (should not revert, idempotent)
        vm.prank(driver1);
        recorder.removeFromBlacklist(stakeholder1);

        assertFalse(recorder.isBlacklisted(driver1, stakeholder1));
    }

    function test_BlacklistPersistsAcrossMultipleRecordAdditions() public {
        // Driver blacklists stakeholder
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Driver records multiple events
        vm.startPrank(driver1);
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventPhoneRight();
        recorder.recordDistractionEventDrinking();
        vm.stopPrank();

        // Stakeholder still cannot access
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);
    }

    function test_BlacklistBeforeAuthorization() public {
        // Create new stakeholder
        address newStakeholder = makeAddr("newStakeholder");

        // Register as stakeholder
        vm.prank(owner);
        registry.registerStakeholder(
            newStakeholder,
            IAccessRegistry.StakeholderRole.TrafficAuthority
        );

        // Driver blacklists BEFORE authorizing
        vm.prank(driver1);
        recorder.blacklistStakeholder(newStakeholder);

        // Now driver authorizes
        vm.prank(driver1);
        registry.addAuthorizedStakeholder(newStakeholder);

        // Driver records event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Stakeholder still cannot access (blacklist takes precedence)
        vm.prank(newStakeholder);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);
    }

    function test_BlacklistAfterAuthorization() public {
        // Stakeholder1 is already authorized (from setUp)
        // Driver records event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Stakeholder can access
        vm.prank(stakeholder1);
        (, , uint256[] memory timestampsBefore) = recorder.getDriverRecords(
            driver1
        );
        assertEq(timestampsBefore.length, 1);

        // Driver blacklists after authorization
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Stakeholder can no longer access
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);
    }

    function test_ComplexScenario_MultipleOperations() public {
        // Driver records initial event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Blacklist stakeholder1
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Stakeholder1 blocked
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);

        // Remove from blacklist
        vm.prank(driver1);
        recorder.removeFromBlacklist(stakeholder1);

        // Stakeholder1 can access again
        vm.prank(stakeholder1);
        (, , uint256[] memory timestamps) = recorder.getDriverRecords(driver1);
        assertEq(timestamps.length, 1);

        // Blacklist again
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Blocked again
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);
    }

    // ============================================
    // CATEGORY 6: Event Emission Tests
    // ============================================

    function test_StakeholderBlacklistedEventEmitted() public {
        vm.expectEmit(true, true, false, true);
        emit StakeholderBlacklisted(driver1, stakeholder1);

        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);
    }

    function test_BlacklistRemovedEventEmitted() public {
        // First blacklist
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Expect removal event
        vm.expectEmit(true, true, false, true);
        emit BlacklistRemoved(driver1, stakeholder1);

        vm.prank(driver1);
        recorder.removeFromBlacklist(stakeholder1);
    }

    function test_MultipleEventsForMultipleOperations() public {
        vm.startPrank(driver1);

        // Expect 3 blacklist events
        vm.expectEmit(true, true, false, true);
        emit StakeholderBlacklisted(driver1, stakeholder1);
        recorder.blacklistStakeholder(stakeholder1);

        vm.expectEmit(true, true, false, true);
        emit StakeholderBlacklisted(driver1, stakeholder2);
        recorder.blacklistStakeholder(stakeholder2);

        vm.expectEmit(true, true, false, true);
        emit StakeholderBlacklisted(driver1, stakeholder3);
        recorder.blacklistStakeholder(stakeholder3);

        // Expect 1 removal event
        vm.expectEmit(true, true, false, true);
        emit BlacklistRemoved(driver1, stakeholder2);
        recorder.removeFromBlacklist(stakeholder2);

        vm.stopPrank();
    }

    // ============================================
    // CATEGORY 7: Advanced Integration Tests (DistractionRecorder + AccessRegistry)
    // ============================================

    // --- AccessRegistry State Changes ---

    function test_RevokedStakeholderCannotAccessRecords() public {
        // Driver records event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Stakeholder1 can initially access (registered and authorized)
        vm.prank(stakeholder1);
        (, , uint256[] memory timestampsBefore) = recorder.getDriverRecords(
            driver1
        );
        assertEq(timestampsBefore.length, 1);

        // Owner revokes stakeholder1's role in AccessRegistry
        vm.prank(owner);
        registry.revokeStakeholder(stakeholder1);

        // Stakeholder1 can no longer access (not registered)
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.UnauthorizedStakeholder.selector);
        recorder.getDriverRecords(driver1);
    }

    function test_DeauthorizedStakeholderCannotAccessRecords() public {
        // Driver records event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Stakeholder1 can initially access
        vm.prank(stakeholder1);
        (, , uint256[] memory timestampsBefore) = recorder.getDriverRecords(
            driver1
        );
        assertEq(timestampsBefore.length, 1);

        // Driver deauthorizes stakeholder1 in AccessRegistry
        vm.prank(driver1);
        registry.removeAuthorizedStakeholder(stakeholder1);

        // Stakeholder1 can no longer access
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.AccessBlocked.selector);
        recorder.getDriverRecords(driver1);
    }

    function test_BlacklistPersistsAfterReauthorization() public {
        // Driver blacklists stakeholder1
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Driver deauthorizes stakeholder1
        vm.prank(driver1);
        registry.removeAuthorizedStakeholder(stakeholder1);

        // Driver re-authorizes stakeholder1
        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);

        // Driver records event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Stakeholder1 still cannot access (blacklist persists)
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);
    }

    function test_BlacklistPersistsAfterRoleRevocationAndReregistration()
        public
    {
        // Driver blacklists stakeholder1
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Owner revokes stakeholder1
        vm.prank(owner);
        registry.revokeStakeholder(stakeholder1);

        // Owner re-registers stakeholder1 with same role
        vm.prank(owner);
        registry.registerStakeholder(
            stakeholder1,
            IAccessRegistry.StakeholderRole.Police
        );

        // Driver records event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Stakeholder1 still cannot access (blacklist persists despite re-registration)
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);
    }

    // --- Vehicle Number Integration ---

    function test_RecordedEventContainsCorrectVehicleNumber() public {
        // Expect event with correct vehicle number from AccessRegistry
        vm.expectEmit(true, true, true, true);
        emit DistractedDrivingRecorded(
            driver1,
            "ABC123", // Vehicle number set in setUp
            DistractionRecorder.EventClass.TextingRight,
            block.timestamp,
            0
        );

        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();
    }

    function test_UpdatedVehicleNumberReflectsInNewEvents() public {
        // Driver records first event with original vehicle number
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Owner updates vehicle number
        vm.prank(owner);
        registry.updateVehicleForDriver(driver1, "NEW999");

        // Expect new event with updated vehicle number
        vm.expectEmit(true, true, true, true);
        emit DistractedDrivingRecorded(
            driver1,
            "NEW999", // Updated vehicle number
            DistractionRecorder.EventClass.PhoneRight,
            block.timestamp,
            1
        );

        vm.prank(driver1);
        recorder.recordDistractionEventPhoneRight();
    }

    function test_MultipleDriversHaveCorrectVehicleNumbers() public {
        // Driver1 records event
        vm.expectEmit(true, true, true, true);
        emit DistractedDrivingRecorded(
            driver1,
            "ABC123",
            DistractionRecorder.EventClass.TextingRight,
            block.timestamp,
            0
        );
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Driver2 records event
        vm.expectEmit(true, true, true, true);
        emit DistractedDrivingRecorded(
            driver2,
            "XYZ789",
            DistractionRecorder.EventClass.PhoneRight,
            block.timestamp,
            0
        );
        vm.prank(driver2);
        recorder.recordDistractionEventPhoneRight();
    }

    // --- Check Execution Order ---

    function test_CheckOrder_BlacklistBeforeRegistrationCheck() public {
        // Create unregistered stakeholder
        address unregistered = makeAddr("unregistered");

        // Driver blacklists unregistered stakeholder
        vm.prank(driver1);
        recorder.blacklistStakeholder(unregistered);

        // Unregistered stakeholder tries to access
        // Should revert with BlacklistedStakeholder (not UnauthorizedStakeholder)
        vm.prank(unregistered);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);
    }

    function test_CheckOrder_RegistrationBeforeAuthorization() public {
        // stakeholder3 is registered but NOT authorized by driver1
        vm.prank(stakeholder3);
        vm.expectRevert(DistractionRecorder.AccessBlocked.selector);
        recorder.getDriverRecords(driver1);
    }

    function test_AllChecksPassForValidAccess() public {
        // Driver records event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Stakeholder1: registered, authorized, not blacklisted
        // All checks should pass
        vm.prank(stakeholder1);
        (, , uint256[] memory timestamps) = recorder.getDriverRecords(driver1);

        assertEq(timestamps.length, 1);
    }

    // --- Unregistered Stakeholder Scenarios ---

    function test_UnregisteredStakeholderCannotAccessRecords() public {
        // Driver records event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Unregistered stakeholder tries to access
        vm.prank(nonStakeholder);
        vm.expectRevert(DistractionRecorder.UnauthorizedStakeholder.selector);
        recorder.getDriverRecords(driver1);
    }

    function test_UnregisteredStakeholderCannotAccessEvenIfAuthorized() public {
        // Driver tries to authorize unregistered stakeholder
        // This should fail in AccessRegistry
        vm.prank(driver1);
        vm.expectRevert(); // AccessRegistry.StakeholderNotRegistered
        registry.addAuthorizedStakeholder(nonStakeholder);
    }

    function test_RegisteredButUnauthorizedStakeholderBlocked() public {
        // stakeholder3 is registered but not authorized by driver1
        // Driver records event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // stakeholder3 tries to access
        vm.prank(stakeholder3);
        vm.expectRevert(DistractionRecorder.AccessBlocked.selector);
        recorder.getDriverRecords(driver1);
    }

    // --- AccessRegistry Updates ---

    function test_CanUpdateAccessRegistryAddress() public {
        // Deploy new AccessRegistry
        vm.prank(owner);
        AccessRegistry newRegistry = new AccessRegistry(owner);

        // Update registry in DistractionRecorder
        vm.prank(owner);
        recorder.setAccessRegistry(address(newRegistry));

        // Verify update
        assertEq(address(recorder.accessRegistry()), address(newRegistry));
    }

    function test_CannotSetAccessRegistryToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(DistractionRecorder.ZeroAddress.selector);
        recorder.setAccessRegistry(address(0));
    }

    function test_OnlyOwnerCanUpdateAccessRegistry() public {
        vm.prank(owner);
        AccessRegistry newRegistry = new AccessRegistry(owner);

        // Non-owner tries to update
        vm.prank(driver1);
        vm.expectRevert(); // Ownable: caller is not the owner
        recorder.setAccessRegistry(address(newRegistry));
    }

    function test_AccessControlWorksWithNewRegistry() public {
        // Deploy and configure new registry
        vm.startPrank(owner);
        AccessRegistry newRegistry = new AccessRegistry(owner);

        // Register stakeholder in new registry
        newRegistry.registerStakeholder(
            stakeholder1,
            IAccessRegistry.StakeholderRole.Police
        );

        // Update vehicle for driver1
        newRegistry.updateVehicleForDriver(driver1, "NEW123");

        // Update recorder to use new registry
        recorder.setAccessRegistry(address(newRegistry));
        vm.stopPrank();

        // Driver authorizes stakeholder1 in new registry
        vm.prank(driver1);
        newRegistry.addAuthorizedStakeholder(stakeholder1);

        // Driver records event
        vm.prank(driver1);
        uint256 recordId = recorder.recordDistractionEventTextingRight();
        assertEq(recordId, 0);

        // Stakeholder1 can access with new registry
        vm.prank(stakeholder1);
        (, , uint256[] memory timestamps) = recorder.getDriverRecords(driver1);
        assertEq(timestamps.length, 1);
    }

    function test_BlacklistPersistsAcrossRegistryUpdate() public {
        // Driver blacklists stakeholder1
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Deploy and set new registry
        vm.startPrank(owner);
        AccessRegistry newRegistry = new AccessRegistry(owner);
        newRegistry.registerStakeholder(
            stakeholder1,
            IAccessRegistry.StakeholderRole.Police
        );
        newRegistry.updateVehicleForDriver(driver1, "NEW123");
        recorder.setAccessRegistry(address(newRegistry));
        vm.stopPrank();

        // Driver authorizes stakeholder1 in new registry
        vm.prank(driver1);
        newRegistry.addAuthorizedStakeholder(stakeholder1);

        // Driver records event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Stakeholder1 still cannot access (blacklist persists across registry change)
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);
    }

    // --- Complex Integration Scenarios ---

    function test_CompleteAccessFlowWithAllContracts() public {
        // Create new stakeholder
        address newStakeholder = makeAddr("newStakeholder");

        // Step 1: Owner registers stakeholder
        vm.prank(owner);
        registry.registerStakeholder(
            newStakeholder,
            IAccessRegistry.StakeholderRole.TrafficAuthority
        );

        // Step 2: Driver authorizes stakeholder
        vm.prank(driver1);
        registry.addAuthorizedStakeholder(newStakeholder);

        // Step 3: Driver records events
        vm.startPrank(driver1);
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventPhoneRight();
        vm.stopPrank();

        // Step 4: Stakeholder can access records
        vm.prank(newStakeholder);
        (, , uint256[] memory timestamps) = recorder.getDriverRecords(driver1);
        assertEq(timestamps.length, 2);

        // Step 5: Driver blacklists stakeholder
        vm.prank(driver1);
        recorder.blacklistStakeholder(newStakeholder);

        // Step 6: Stakeholder cannot access anymore
        vm.prank(newStakeholder);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);

        // Step 7: Driver removes from blacklist
        vm.prank(driver1);
        recorder.removeFromBlacklist(newStakeholder);

        // Step 8: Stakeholder can access again
        vm.prank(newStakeholder);
        (, , uint256[] memory timestamps2) = recorder.getDriverRecords(driver1);
        assertEq(timestamps2.length, 2);

        // Step 9: Driver deauthorizes in AccessRegistry
        vm.prank(driver1);
        registry.removeAuthorizedStakeholder(newStakeholder);

        // Step 10: Stakeholder cannot access (not authorized)
        vm.prank(newStakeholder);
        vm.expectRevert(DistractionRecorder.AccessBlocked.selector);
        recorder.getDriverRecords(driver1);
    }

    function test_MultipleDriversWithDifferentAccessPolicies() public {
        // Driver1 blacklists stakeholder2
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder2);

        // Both drivers record events
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        vm.prank(driver2);
        recorder.recordDistractionEventPhoneRight();

        // Stakeholder2 cannot access driver1 (blacklisted)
        vm.prank(stakeholder2);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecords(driver1);

        // But stakeholder2 was never authorized by driver2, so also blocked
        vm.prank(stakeholder2);
        vm.expectRevert(DistractionRecorder.AccessBlocked.selector);
        recorder.getDriverRecords(driver2);

        // Stakeholder1 can access driver1 (authorized, not blacklisted)
        vm.prank(stakeholder1);
        (, , uint256[] memory timestamps1) = recorder.getDriverRecords(driver1);
        assertEq(timestamps1.length, 1);

        // Stakeholder1 can also access driver2
        vm.prank(stakeholder1);
        (, , uint256[] memory timestamps2) = recorder.getDriverRecords(driver2);
        assertEq(timestamps2.length, 1);
    }

    // ============================================
    // CATEGORY 8: Paginated Query Tests
    // ============================================

    function test_PaginatedQuery_FirstPage() public {
        // Driver records 5 events
        vm.startPrank(driver1);
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventPhoneRight();
        recorder.recordDistractionEventDrinking();
        recorder.recordDistractionEventRadio();
        recorder.recordDistractionEventHairMakeup();
        vm.stopPrank();

        // Stakeholder queries first 3 records (offset=0, limit=3)
        vm.prank(stakeholder1);
        (
            ,
            DistractionRecorder.EventClass[] memory eventClasses,
            uint256[] memory timestamps
        ) = recorder.getDriverRecordsPaginated(driver1, 0, 3);

        assertEq(timestamps.length, 3);
        assertEq(
            uint256(eventClasses[0]),
            uint256(DistractionRecorder.EventClass.TextingRight)
        );
        assertEq(
            uint256(eventClasses[1]),
            uint256(DistractionRecorder.EventClass.PhoneRight)
        );
        assertEq(
            uint256(eventClasses[2]),
            uint256(DistractionRecorder.EventClass.Drinking)
        );
    }

    function test_PaginatedQuery_SecondPage() public {
        // Driver records 5 events
        vm.startPrank(driver1);
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventPhoneRight();
        recorder.recordDistractionEventDrinking();
        recorder.recordDistractionEventRadio();
        recorder.recordDistractionEventHairMakeup();
        vm.stopPrank();

        // Stakeholder queries second page (offset=3, limit=3)
        vm.prank(stakeholder1);
        (
            ,
            DistractionRecorder.EventClass[] memory eventClasses,
            uint256[] memory timestamps
        ) = recorder.getDriverRecordsPaginated(driver1, 3, 3);

        // Should return only 2 records (total is 5, offset is 3)
        assertEq(timestamps.length, 2);
        assertEq(
            uint256(eventClasses[0]),
            uint256(DistractionRecorder.EventClass.Radio)
        );
        assertEq(
            uint256(eventClasses[1]),
            uint256(DistractionRecorder.EventClass.HairMakeup)
        );
    }

    function test_PaginatedQuery_OffsetBeyondRecords() public {
        // Driver records 3 events
        vm.startPrank(driver1);
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventPhoneRight();
        recorder.recordDistractionEventDrinking();
        vm.stopPrank();

        // Stakeholder queries with offset beyond records (offset=10, limit=5)
        vm.prank(stakeholder1);
        (
            string[] memory vehicleNumbers,
            DistractionRecorder.EventClass[] memory eventClasses,
            uint256[] memory timestamps
        ) = recorder.getDriverRecordsPaginated(driver1, 10, 5);

        // Should return empty arrays
        assertEq(timestamps.length, 0);
        assertEq(eventClasses.length, 0);
        assertEq(vehicleNumbers.length, 0);
    }

    function test_PaginatedQuery_LimitExceedsTotalRecords() public {
        // Driver records 3 events
        vm.startPrank(driver1);
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventPhoneRight();
        recorder.recordDistractionEventDrinking();
        vm.stopPrank();

        // Stakeholder queries with limit > total records (offset=0, limit=100)
        vm.prank(stakeholder1);
        (
            ,
            ,
            uint256[] memory timestamps
        ) = recorder.getDriverRecordsPaginated(driver1, 0, 100);

        // Should return all 3 records
        assertEq(timestamps.length, 3);
    }

    function test_PaginatedQuery_BlacklistedStakeholderBlocked() public {
        // Driver records events
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Driver blacklists stakeholder1
        vm.prank(driver1);
        recorder.blacklistStakeholder(stakeholder1);

        // Stakeholder1 tries to access paginated records
        vm.prank(stakeholder1);
        vm.expectRevert(DistractionRecorder.BlacklistedStakeholder.selector);
        recorder.getDriverRecordsPaginated(driver1, 0, 10);
    }

    function test_PaginatedQuery_UnauthorizedStakeholderBlocked() public {
        // Driver records event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // stakeholder3 is registered but not authorized by driver1
        vm.prank(stakeholder3);
        vm.expectRevert(DistractionRecorder.AccessBlocked.selector);
        recorder.getDriverRecordsPaginated(driver1, 0, 10);
    }

    function test_PaginatedQuery_UnregisteredStakeholderBlocked() public {
        // Driver records event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Unregistered stakeholder tries to access
        vm.prank(nonStakeholder);
        vm.expectRevert(DistractionRecorder.UnauthorizedStakeholder.selector);
        recorder.getDriverRecordsPaginated(driver1, 0, 10);
    }

    function test_PaginatedQuery_EmptyRecords() public {
        // Driver has no records yet

        // Stakeholder queries records (should return empty arrays)
        vm.prank(stakeholder1);
        (
            string[] memory vehicleNumbers,
            DistractionRecorder.EventClass[] memory eventClasses,
            uint256[] memory timestamps
        ) = recorder.getDriverRecordsPaginated(driver1, 0, 10);

        assertEq(timestamps.length, 0);
        assertEq(eventClasses.length, 0);
        assertEq(vehicleNumbers.length, 0);
    }

    function test_PaginatedQuery_SingleRecord() public {
        // Driver records single event
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        // Stakeholder queries with pagination
        vm.prank(stakeholder1);
        (
            ,
            DistractionRecorder.EventClass[] memory eventClasses,
            uint256[] memory timestamps
        ) = recorder.getDriverRecordsPaginated(driver1, 0, 10);

        assertEq(timestamps.length, 1);
        assertEq(
            uint256(eventClasses[0]),
            uint256(DistractionRecorder.EventClass.TextingRight)
        );
    }

    function test_PaginatedQuery_VehicleNumbersIncluded() public {
        // Driver records events (vehicle number should be "ABC123" from setUp)
        vm.startPrank(driver1);
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventPhoneRight();
        vm.stopPrank();

        // Stakeholder queries records
        vm.prank(stakeholder1);
        (
            string[] memory vehicleNumbers,
            ,

        ) = recorder.getDriverRecordsPaginated(driver1, 0, 10);

        assertEq(vehicleNumbers.length, 2);
        assertEq(vehicleNumbers[0], "ABC123");
        assertEq(vehicleNumbers[1], "ABC123");
    }

    function test_PaginatedQuery_CompareWithFullQuery() public {
        // Driver records 10 events
        vm.startPrank(driver1);
        for (uint256 i = 0; i < 10; i++) {
            recorder.recordDistractionEventTextingRight();
        }
        vm.stopPrank();

        // Get all records with full query
        vm.prank(stakeholder1);
        (
            ,
            ,
            uint256[] memory allTimestamps
        ) = recorder.getDriverRecords(driver1);

        // Get all records with paginated query (offset=0, limit=100)
        vm.prank(stakeholder1);
        (
            ,
            ,
            uint256[] memory paginatedTimestamps
        ) = recorder.getDriverRecordsPaginated(driver1, 0, 100);

        // Should be identical
        assertEq(allTimestamps.length, paginatedTimestamps.length);
        assertEq(allTimestamps.length, 10);

        for (uint256 i = 0; i < 10; i++) {
            assertEq(allTimestamps[i], paginatedTimestamps[i]);
        }
    }
}
