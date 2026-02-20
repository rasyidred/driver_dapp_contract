// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {AccessRegistry} from "../src/AccessRegistry.sol";
import {IAccessRegistry} from "../src/interfaces/IAccessRegistry.sol";
import {IDistractionRecorder} from "../src/interfaces/IDistractionRecorder.sol";
import {MockDistractionRecorder} from "./mocks/MockDistractionRecorder.sol";

contract AccessRegistryTest is Test {
    AccessRegistry public registry;
    MockDistractionRecorder public mockRecorder;

    address public owner;
    address public driver1;
    address public driver2;
    address public stakeholder1;
    address public stakeholder2;
    address public stakeholder3;
    address public stakeholder4;
    address public nonStakeholder;

    event StakeholderRegistered(address indexed stakeholder, IAccessRegistry.StakeholderRole indexed role);
    event StakeholderRevoked(address indexed stakeholder);
    event StakeholderAuthorized(address indexed driver, address indexed stakeholder);
    event StakeholderDeauthorized(address indexed driver, address indexed stakeholder);
    event VehicleNumberUpdated(address indexed driver, string indexed vehicleNumber, uint256 indexed timestamp);
    event DistractionRecorderUpdated(address indexed newRecorder);

    function setUp() public {
        owner = makeAddr("owner");
        driver1 = makeAddr("driver1");
        driver2 = makeAddr("driver2");
        stakeholder1 = makeAddr("stakeholder1");
        stakeholder2 = makeAddr("stakeholder2");
        stakeholder3 = makeAddr("stakeholder3");
        stakeholder4 = makeAddr("stakeholder4");
        nonStakeholder = makeAddr("nonStakeholder");

        vm.startPrank(owner);
        registry = new AccessRegistry(owner);
        mockRecorder = new MockDistractionRecorder();
        registry.setDistractionRecorder(address(mockRecorder));
        vm.stopPrank();
    }

    function _setupMultipleStakeholders() internal {
        vm.startPrank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);
        registry.registerStakeholder(stakeholder2, IAccessRegistry.StakeholderRole.LawEnforcement);
        registry.registerStakeholder(stakeholder3, IAccessRegistry.StakeholderRole.FleetManager);
        registry.registerStakeholder(stakeholder4, IAccessRegistry.StakeholderRole.RegulatoryBody);
        vm.stopPrank();
    }

    function _authorizeStakeholder(address driver, address stakeholder) internal {
        vm.prank(driver);
        registry.addAuthorizedStakeholder(stakeholder);
    }

    function _setupMockRecords(address driver, uint256 count) internal {
        mockRecorder.setMockRecordCount(driver, count);
        IDistractionRecorder.DistractionRecord[] memory records =
            new IDistractionRecorder.DistractionRecord[](count);
        for (uint256 i = 0; i < count; i++) {
            records[i] = IDistractionRecorder.DistractionRecord({
                vehicleNumber: "TEST-001",
                eventClass: IDistractionRecorder.EventClass.TextingRight,
                timestamp: block.timestamp
            });
        }
        mockRecorder.setMockRecords(driver, records);
    }

    // ============================================
    // CATEGORY 1: Constructor & Initialization
    // ============================================

    function test_Constructor_SetsOwnerCorrectly() public view {
        assertEq(registry.owner(), owner);
    }

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert("AR_ZeroAddress");
        new AccessRegistry(address(0));
    }

    function test_Constructor_InitialStateIsEmpty() public view {
        assertFalse(registry.isRegisteredStakeholder(stakeholder1));
        assertEq(uint256(registry.getStakeholderRole(stakeholder1)), uint256(IAccessRegistry.StakeholderRole.None));
        assertEq(registry.getDriverVehicleNumber(driver1), "");
    }

    // ============================================
    // CATEGORY 2: Stakeholder Registration
    // ============================================

    function test_RegisterStakeholder_RegistersInsuranceCompany() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        assertTrue(registry.isRegisteredStakeholder(stakeholder1));
        assertEq(
            uint256(registry.getStakeholderRole(stakeholder1)),
            uint256(IAccessRegistry.StakeholderRole.InsuranceCompany)
        );
    }

    function test_RegisterStakeholder_RegistersLawEnforcement() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder2, IAccessRegistry.StakeholderRole.LawEnforcement);

        assertTrue(registry.isRegisteredStakeholder(stakeholder2));
        assertEq(
            uint256(registry.getStakeholderRole(stakeholder2)), uint256(IAccessRegistry.StakeholderRole.LawEnforcement)
        );
    }

    function test_RegisterStakeholder_RegistersFleetManager() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder3, IAccessRegistry.StakeholderRole.FleetManager);

        assertTrue(registry.isRegisteredStakeholder(stakeholder3));
        assertEq(
            uint256(registry.getStakeholderRole(stakeholder3)), uint256(IAccessRegistry.StakeholderRole.FleetManager)
        );
    }

    function test_RegisterStakeholder_RegistersRegulatoryBody() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder4, IAccessRegistry.StakeholderRole.RegulatoryBody);

        assertTrue(registry.isRegisteredStakeholder(stakeholder4));
        assertEq(
            uint256(registry.getStakeholderRole(stakeholder4)), uint256(IAccessRegistry.StakeholderRole.RegulatoryBody)
        );
    }

    function test_RegisterStakeholder_EmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit StakeholderRegistered(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);
    }

    function test_RegisterStakeholder_RevertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("AR_ZeroAddress");
        registry.registerStakeholder(address(0), IAccessRegistry.StakeholderRole.InsuranceCompany);
    }

    function test_RegisterStakeholder_RevertsOnNoneRole() public {
        vm.prank(owner);
        vm.expectRevert("AR_InvalidRole");
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.None);
    }

    function test_RegisterStakeholder_RevertsWhenCalledByNonOwner() public {
        vm.prank(nonStakeholder);
        vm.expectRevert();
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);
    }

    function test_RegisterStakeholder_CanOverwriteExistingRole() public {
        vm.startPrank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.LawEnforcement);
        vm.stopPrank();

        assertEq(
            uint256(registry.getStakeholderRole(stakeholder1)), uint256(IAccessRegistry.StakeholderRole.LawEnforcement)
        );
    }

    // ============================================
    // CATEGORY 3: Stakeholder Revocation
    // ============================================

    function test_RevokeStakeholder_RevokesRegisteredStakeholder() public {
        vm.startPrank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);
        registry.revokeStakeholder(stakeholder1);
        vm.stopPrank();

        assertFalse(registry.isRegisteredStakeholder(stakeholder1));
    }

    function test_RevokeStakeholder_EmitsEvent() public {
        vm.startPrank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.expectEmit(true, false, false, true);
        emit StakeholderRevoked(stakeholder1);
        registry.revokeStakeholder(stakeholder1);
        vm.stopPrank();
    }

    function test_RevokeStakeholder_RevertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("AR_ZeroAddress");
        registry.revokeStakeholder(address(0));
    }

    function test_RevokeStakeholder_RevertsOnNotRegistered() public {
        vm.prank(owner);
        vm.expectRevert("AR_NotRegistered");
        registry.revokeStakeholder(stakeholder1);
    }

    function test_RevokeStakeholder_RevertsWhenCalledByNonOwner() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.prank(nonStakeholder);
        vm.expectRevert();
        registry.revokeStakeholder(stakeholder1);
    }

    function test_RevokeStakeholder_SetsRoleToNone() public {
        vm.startPrank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);
        registry.revokeStakeholder(stakeholder1);
        vm.stopPrank();

        assertEq(uint256(registry.getStakeholderRole(stakeholder1)), uint256(IAccessRegistry.StakeholderRole.None));
    }

    // ============================================
    // CATEGORY 4: Vehicle Management
    // ============================================

    function test_UpdateVehicleForDriver_UpdatesVehicleNumber() public {
        vm.prank(owner);
        registry.updateVehicleForDriver(driver1, "ABC-123");

        assertEq(registry.getDriverVehicleNumber(driver1), "ABC-123");
    }

    function test_UpdateVehicleForDriver_EmitsEventWithTimestamp() public {
        uint256 currentTimestamp = block.timestamp;

        vm.expectEmit(true, true, true, true);
        emit VehicleNumberUpdated(driver1, "ABC-123", currentTimestamp);

        vm.prank(owner);
        registry.updateVehicleForDriver(driver1, "ABC-123");
    }

    function test_UpdateVehicleForDriver_RevertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("AR_ZeroAddress");
        registry.updateVehicleForDriver(address(0), "ABC-123");
    }

    function test_UpdateVehicleForDriver_RevertsWhenCalledByNonOwner() public {
        vm.prank(nonStakeholder);
        vm.expectRevert();
        registry.updateVehicleForDriver(driver1, "ABC-123");
    }

    function test_UpdateVehicleForDriver_CanUpdateExistingVehicle() public {
        vm.startPrank(owner);
        registry.updateVehicleForDriver(driver1, "ABC-123");
        registry.updateVehicleForDriver(driver1, "XYZ-789");
        vm.stopPrank();

        assertEq(registry.getDriverVehicleNumber(driver1), "XYZ-789");
    }

    function test_UpdateVehicleForDriver_AcceptsEmptyString() public {
        vm.prank(owner);
        registry.updateVehicleForDriver(driver1, "");

        assertEq(registry.getDriverVehicleNumber(driver1), "");
    }

    // ============================================
    // CATEGORY 5: DistractionRecorder Management
    // ============================================

    function test_SetDistractionRecorder_UpdatesAddress() public view {
        assertEq(registry.distractionRecorder(), address(mockRecorder));
    }

    function test_SetDistractionRecorder_EmitsEvent() public {
        MockDistractionRecorder newMockRecorder = new MockDistractionRecorder();

        vm.expectEmit(true, false, false, true);
        emit DistractionRecorderUpdated(address(newMockRecorder));

        vm.prank(owner);
        registry.setDistractionRecorder(address(newMockRecorder));
    }

    function test_SetDistractionRecorder_RevertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("AR_ZeroAddress");
        registry.setDistractionRecorder(address(0));
    }

    function test_SetDistractionRecorder_RevertsWhenCalledByNonOwner() public {
        MockDistractionRecorder newMockRecorder = new MockDistractionRecorder();

        vm.prank(nonStakeholder);
        vm.expectRevert();
        registry.setDistractionRecorder(address(newMockRecorder));
    }

    function test_SetDistractionRecorder_CanUpdateExistingRecorder() public {
        MockDistractionRecorder newMockRecorder = new MockDistractionRecorder();

        vm.prank(owner);
        registry.setDistractionRecorder(address(newMockRecorder));

        assertEq(registry.distractionRecorder(), address(newMockRecorder));
    }

    // ============================================
    // CATEGORY 6: Driver Authorization
    // ============================================

    function test_AddAuthorizedStakeholder_AuthorizesStakeholder() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);

        assertTrue(registry.isAuthorized(driver1, stakeholder1));
    }

    function test_AddAuthorizedStakeholder_EmitsEvent() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.expectEmit(true, true, false, true);
        emit StakeholderAuthorized(driver1, stakeholder1);

        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);
    }

    function test_AddAuthorizedStakeholder_RevertsOnZeroAddress() public {
        vm.prank(driver1);
        vm.expectRevert("AR_ZeroAddress");
        registry.addAuthorizedStakeholder(address(0));
    }

    function test_AddAuthorizedStakeholder_RevertsOnUnknownEntity() public {
        vm.prank(driver1);
        vm.expectRevert("AR_UnknownEntity");
        registry.addAuthorizedStakeholder(stakeholder1);
    }

    function test_AddAuthorizedStakeholder_CanAuthorizeMultipleStakeholders() public {
        _setupMultipleStakeholders();

        vm.startPrank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);
        registry.addAuthorizedStakeholder(stakeholder2);
        registry.addAuthorizedStakeholder(stakeholder3);
        vm.stopPrank();

        assertTrue(registry.isAuthorized(driver1, stakeholder1));
        assertTrue(registry.isAuthorized(driver1, stakeholder2));
        assertTrue(registry.isAuthorized(driver1, stakeholder3));
    }

    function test_AddAuthorizedStakeholder_IdempotentOperation() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.startPrank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);
        registry.addAuthorizedStakeholder(stakeholder1);
        vm.stopPrank();

        assertTrue(registry.isAuthorized(driver1, stakeholder1));
    }

    // ============================================
    // CATEGORY 7: Driver Deauthorization
    // ============================================

    function test_RemoveAuthorizedStakeholder_DeauthorizesStakeholder() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.startPrank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);
        registry.removeAuthorizedStakeholder(stakeholder1);
        vm.stopPrank();

        assertFalse(registry.isAuthorized(driver1, stakeholder1));
    }

    function test_RemoveAuthorizedStakeholder_EmitsEvent() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.startPrank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);

        vm.expectEmit(true, true, false, true);
        emit StakeholderDeauthorized(driver1, stakeholder1);
        registry.removeAuthorizedStakeholder(stakeholder1);
        vm.stopPrank();
    }

    function test_RemoveAuthorizedStakeholder_RevertsOnZeroAddress() public {
        vm.prank(driver1);
        vm.expectRevert("AR_ZeroAddress");
        registry.removeAuthorizedStakeholder(address(0));
    }

    function test_RemoveAuthorizedStakeholder_IdempotentOperation() public {
        vm.startPrank(driver1);
        registry.removeAuthorizedStakeholder(stakeholder1);
        registry.removeAuthorizedStakeholder(stakeholder1);
        vm.stopPrank();

        assertFalse(registry.isAuthorized(driver1, stakeholder1));
    }

    function test_RemoveAuthorizedStakeholder_DoesNotRequireRegistration() public {
        vm.prank(driver1);
        registry.removeAuthorizedStakeholder(stakeholder1);

        assertFalse(registry.isAuthorized(driver1, stakeholder1));
    }

    // ============================================
    // CATEGORY 8: View Functions
    // ============================================

    function test_IsAuthorized_ReturnsTrueWhenAuthorized() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);

        assertTrue(registry.isAuthorized(driver1, stakeholder1));
    }

    function test_IsAuthorized_ReturnsFalseWhenNotAuthorized() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        assertFalse(registry.isAuthorized(driver1, stakeholder1));
    }

    function test_IsAuthorized_ReturnsFalseForRevokedStakeholder() public {
        vm.startPrank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);
        vm.stopPrank();

        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);

        vm.prank(owner);
        registry.revokeStakeholder(stakeholder1);

        assertTrue(registry.isAuthorized(driver1, stakeholder1));
    }

    function test_IsRegisteredStakeholder_ReturnsTrueWhenRegistered() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        assertTrue(registry.isRegisteredStakeholder(stakeholder1));
    }

    function test_IsRegisteredStakeholder_ReturnsFalseWhenNotRegistered() public view {
        assertFalse(registry.isRegisteredStakeholder(stakeholder1));
    }

    function test_IsRegisteredStakeholder_ReturnsFalseAfterRevocation() public {
        vm.startPrank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);
        registry.revokeStakeholder(stakeholder1);
        vm.stopPrank();

        assertFalse(registry.isRegisteredStakeholder(stakeholder1));
    }

    function test_GetStakeholderRole_ReturnsCorrectRole() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.LawEnforcement);

        assertEq(
            uint256(registry.getStakeholderRole(stakeholder1)), uint256(IAccessRegistry.StakeholderRole.LawEnforcement)
        );
    }

    function test_GetStakeholderRole_ReturnsNoneForUnregistered() public view {
        assertEq(uint256(registry.getStakeholderRole(stakeholder1)), uint256(IAccessRegistry.StakeholderRole.None));
    }

    function test_GetDriverVehicleNumber_ReturnsCorrectVehicle() public {
        vm.prank(owner);
        registry.updateVehicleForDriver(driver1, "ABC-123");

        assertEq(registry.getDriverVehicleNumber(driver1), "ABC-123");
    }

    function test_GetDriverVehicleNumber_ReturnsEmptyForUnsetDriver() public view {
        assertEq(registry.getDriverVehicleNumber(driver1), "");
    }

    // ============================================
    // CATEGORY 9: Data Gateway - Access Control
    // ============================================

    function test_GetDistractedDrivingEvents_DriverCanQueryOwnRecords() public {
        _setupMockRecords(driver1, 5);

        vm.prank(driver1);
        (IDistractionRecorder.DistractionRecord[] memory records, uint256 totalCount) =
            registry.getDistractedDrivingEvents(driver1, 0, 10);

        assertEq(records.length, 5);
        assertEq(totalCount, 5);
    }

    function test_GetDistractedDrivingEvents_AuthorizedStakeholderCanQuery() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);

        _setupMockRecords(driver1, 3);

        vm.prank(stakeholder1);
        (IDistractionRecorder.DistractionRecord[] memory records, uint256 totalCount) =
            registry.getDistractedDrivingEvents(driver1, 0, 10);

        assertEq(records.length, 3);
        assertEq(totalCount, 3);
    }

    function test_GetDistractedDrivingEvents_RevertsWhenRecorderNotSet() public {
        vm.prank(owner);
        registry.setDistractionRecorder(address(0));

        vm.prank(driver1);
        vm.expectRevert("AR_RecorderNotSet");
        registry.getDistractedDrivingEvents(driver1, 0, 10);
    }

    function test_GetDistractedDrivingEvents_RevertsForUnregisteredStakeholder() public {
        vm.prank(nonStakeholder);
        vm.expectRevert("AR_UnauthorizedStakeholder");
        registry.getDistractedDrivingEvents(driver1, 0, 10);
    }

    function test_GetDistractedDrivingEvents_RevertsForNotAuthorizedByDriver() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.prank(stakeholder1);
        vm.expectRevert("AR_AccessDenied");
        registry.getDistractedDrivingEvents(driver1, 0, 10);
    }

    function test_GetDistractedDrivingEvents_ReturnsRecordsAndTotalCount() public {
        _setupMockRecords(driver1, 10);

        vm.prank(driver1);
        (IDistractionRecorder.DistractionRecord[] memory records, uint256 totalCount) =
            registry.getDistractedDrivingEvents(driver1, 0, 5);

        assertEq(records.length, 5);
        assertEq(totalCount, 10);
    }

    function test_GetDistractedDrivingEvents_ProxiesToDistractionRecorder() public {
        _setupMockRecords(driver1, 5);

        mockRecorder.resetCallTracking();

        vm.prank(driver1);
        registry.getDistractedDrivingEvents(driver1, 2, 3);

        assertEq(mockRecorder.getDriverRecordsCallCount(), 1);
        assertEq(mockRecorder.lastQueriedDriver(), driver1);
        assertEq(mockRecorder.lastOffset(), 2);
        assertEq(mockRecorder.lastLimit(), 3);
    }

    // ============================================
    // CATEGORY 10: Multi-Driver Scenarios
    // ============================================

    function test_MultiDriver_IndependentAuthorizations() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);

        assertTrue(registry.isAuthorized(driver1, stakeholder1));
        assertFalse(registry.isAuthorized(driver2, stakeholder1));
    }

    function test_MultiDriver_IndependentVehicleNumbers() public {
        vm.startPrank(owner);
        registry.updateVehicleForDriver(driver1, "ABC-123");
        registry.updateVehicleForDriver(driver2, "XYZ-789");
        vm.stopPrank();

        assertEq(registry.getDriverVehicleNumber(driver1), "ABC-123");
        assertEq(registry.getDriverVehicleNumber(driver2), "XYZ-789");
    }

    function test_MultiDriver_StakeholderCanAccessMultipleDrivers() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);

        vm.prank(driver2);
        registry.addAuthorizedStakeholder(stakeholder1);

        _setupMockRecords(driver1, 3);
        _setupMockRecords(driver2, 5);

        vm.startPrank(stakeholder1);
        (, uint256 count1) = registry.getDistractedDrivingEvents(driver1, 0, 10);
        (, uint256 count2) = registry.getDistractedDrivingEvents(driver2, 0, 10);
        vm.stopPrank();

        assertEq(count1, 3);
        assertEq(count2, 5);
    }

    // ============================================
    // CATEGORY 11: Integration & Edge Cases
    // ============================================

    function test_EdgeCase_AuthorizeBeforeRegister() public {
        vm.prank(driver1);
        vm.expectRevert("AR_UnknownEntity");
        registry.addAuthorizedStakeholder(stakeholder1);
    }

    function test_EdgeCase_RevokeRemovesAuthorizationEffect() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);

        vm.prank(owner);
        registry.revokeStakeholder(stakeholder1);

        vm.prank(stakeholder1);
        vm.expectRevert("AR_UnauthorizedStakeholder");
        registry.getDistractedDrivingEvents(driver1, 0, 10);
    }

    function test_EdgeCase_ReRegisterAfterRevoke() public {
        vm.startPrank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);
        vm.stopPrank();

        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);

        vm.startPrank(owner);
        registry.revokeStakeholder(stakeholder1);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.LawEnforcement);
        vm.stopPrank();

        assertTrue(registry.isAuthorized(driver1, stakeholder1));
        assertEq(
            uint256(registry.getStakeholderRole(stakeholder1)), uint256(IAccessRegistry.StakeholderRole.LawEnforcement)
        );
    }

    function test_Integration_CompleteWorkflow() public {
        vm.startPrank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);
        registry.updateVehicleForDriver(driver1, "ABC-123");
        vm.stopPrank();

        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);

        _setupMockRecords(driver1, 5);

        vm.prank(stakeholder1);
        (IDistractionRecorder.DistractionRecord[] memory records, uint256 totalCount) =
            registry.getDistractedDrivingEvents(driver1, 0, 10);

        assertEq(records.length, 5);
        assertEq(totalCount, 5);

        vm.prank(driver1);
        registry.removeAuthorizedStakeholder(stakeholder1);

        vm.prank(stakeholder1);
        vm.expectRevert("AR_AccessDenied");
        registry.getDistractedDrivingEvents(driver1, 0, 10);
    }

    function test_Integration_MultipleStakeholdersOneDriver() public {
        _setupMultipleStakeholders();

        vm.startPrank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);
        registry.addAuthorizedStakeholder(stakeholder2);
        vm.stopPrank();

        _setupMockRecords(driver1, 3);

        vm.prank(stakeholder1);
        (, uint256 count1) = registry.getDistractedDrivingEvents(driver1, 0, 10);

        vm.prank(stakeholder2);
        (, uint256 count2) = registry.getDistractedDrivingEvents(driver1, 0, 10);

        assertEq(count1, 3);
        assertEq(count2, 3);

        vm.prank(stakeholder3);
        vm.expectRevert("AR_AccessDenied");
        registry.getDistractedDrivingEvents(driver1, 0, 10);
    }

    function test_Integration_OneStakeholderMultipleDrivers() public {
        vm.prank(owner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.LawEnforcement);

        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);

        vm.prank(driver2);
        registry.addAuthorizedStakeholder(stakeholder1);

        _setupMockRecords(driver1, 2);
        _setupMockRecords(driver2, 4);

        vm.startPrank(stakeholder1);
        (, uint256 count1) = registry.getDistractedDrivingEvents(driver1, 0, 10);
        (, uint256 count2) = registry.getDistractedDrivingEvents(driver2, 0, 10);
        vm.stopPrank();

        assertEq(count1, 2);
        assertEq(count2, 4);
    }

    function test_Integration_OwnershipTransfer() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        registry.transferOwnership(newOwner);

        assertEq(registry.owner(), newOwner);

        vm.prank(newOwner);
        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.InsuranceCompany);

        assertTrue(registry.isRegisteredStakeholder(stakeholder1));
    }

    function test_Integration_RecorderUpdate() public {
        MockDistractionRecorder newMockRecorder = new MockDistractionRecorder();
        _setupMockRecords(driver1, 3);

        vm.prank(driver1);
        (, uint256 oldCount) = registry.getDistractedDrivingEvents(driver1, 0, 10);
        assertEq(oldCount, 3);

        newMockRecorder.setMockRecordCount(driver1, 7);
        IDistractionRecorder.DistractionRecord[] memory newRecords =
            new IDistractionRecorder.DistractionRecord[](7);
        for (uint256 i = 0; i < 7; i++) {
            newRecords[i] = IDistractionRecorder.DistractionRecord({
                vehicleNumber: "NEW-999",
                eventClass: IDistractionRecorder.EventClass.Drinking,
                timestamp: block.timestamp
            });
        }
        newMockRecorder.setMockRecords(driver1, newRecords);

        vm.prank(owner);
        registry.setDistractionRecorder(address(newMockRecorder));

        vm.prank(driver1);
        (, uint256 newCount) = registry.getDistractedDrivingEvents(driver1, 0, 10);
        assertEq(newCount, 7);
    }

    function test_Integration_VehicleNumberChange() public {
        vm.startPrank(owner);
        registry.updateVehicleForDriver(driver1, "ABC-123");
        vm.stopPrank();

        assertEq(registry.getDriverVehicleNumber(driver1), "ABC-123");

        vm.prank(owner);
        registry.updateVehicleForDriver(driver1, "NEW-456");

        assertEq(registry.getDriverVehicleNumber(driver1), "NEW-456");
    }
}
