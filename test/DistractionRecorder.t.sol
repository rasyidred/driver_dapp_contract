// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {DistractionRecorder} from "../src/DistractionRecorder.sol";
import {AccessRegistry} from "../src/AccessRegistry.sol";
import {IAccessRegistry} from "../src/interfaces/IAccessRegistry.sol";
import {IDistractionRecorder} from "../src/interfaces/IDistractionRecorder.sol";

contract DistractionRecorderTest is Test {
    DistractionRecorder public recorder;
    AccessRegistry public registry;

    address public owner;
    address public driver1;
    address public driver2;
    address public stakeholder1;
    address public unauthorizedCaller;

    event DistractedDrivingRecorded(
        address indexed driver,
        string indexed vehicleNumber,
        IDistractionRecorder.EventClass indexed eventClass,
        uint256 timestamp,
        uint256 recordId
    );
    event SafeDrivingRecorded(
        address indexed driver, string indexed vehicleNumber, uint256 indexed timestamp, uint256 elapsedTime
    );
    event AccessRegistryUpdated(address indexed newRegistry);

    function setUp() public {
        owner = makeAddr("owner");
        driver1 = makeAddr("driver1");
        driver2 = makeAddr("driver2");
        stakeholder1 = makeAddr("stakeholder1");
        unauthorizedCaller = makeAddr("unauthorizedCaller");

        vm.startPrank(owner);
        registry = new AccessRegistry(owner);
        recorder = new DistractionRecorder(owner, address(registry));
        registry.setDistractionRecorder(address(recorder));

        registry.registerStakeholder(stakeholder1, IAccessRegistry.StakeholderRole.LawEnforcement);
        registry.updateVehicleForDriver(driver1, "ABC-123");
        registry.updateVehicleForDriver(driver2, "XYZ-789");
        vm.stopPrank();

        vm.prank(driver1);
        registry.addAuthorizedStakeholder(stakeholder1);
    }

    function _recordMultipleEvents(address driver, uint256 count) internal returns (uint256[] memory) {
        uint256[] memory recordIds = new uint256[](count);
        vm.startPrank(driver);
        for (uint256 i = 0; i < count; i++) {
            recordIds[i] = recorder.recordDistractionEventTextingRight();
        }
        vm.stopPrank();
        return recordIds;
    }

    function _verifyRecordData(
        IDistractionRecorder.DistractionRecord memory record,
        string memory expectedVehicle,
        IDistractionRecorder.EventClass expectedClass,
        uint256 expectedTimestamp
    ) internal pure {
        assertEq(record.vehicleNumber, expectedVehicle);
        assertEq(uint256(record.eventClass), uint256(expectedClass));
        assertEq(record.timestamp, expectedTimestamp);
    }

    // ============================================
    // CATEGORY 1: Constructor & Initialization
    // ============================================

    function test_Constructor_SetsOwnerCorrectly() public view {
        assertEq(recorder.owner(), owner);
    }

    function test_Constructor_SetsAccessRegistryCorrectly() public view {
        assertEq(address(recorder.accessRegistry()), address(registry));
    }

    function test_Constructor_RevertsOnZeroOwner() public {
        vm.expectRevert();
        new DistractionRecorder(address(0), address(registry));
    }

    function test_Constructor_RevertsOnZeroRegistry() public {
        vm.expectRevert("DR_ZeroAddress");
        new DistractionRecorder(owner, address(0));
    }

    // ============================================
    // CATEGORY 2: AccessRegistry Management
    // ============================================

    function test_SetAccessRegistry_UpdatesRegistry() public {
        AccessRegistry newRegistry = new AccessRegistry(owner);

        vm.prank(owner);
        recorder.setAccessRegistry(address(newRegistry));

        assertEq(address(recorder.accessRegistry()), address(newRegistry));
    }

    function test_SetAccessRegistry_EmitsEvent() public {
        AccessRegistry newRegistry = new AccessRegistry(owner);

        vm.expectEmit(true, false, false, true);
        emit AccessRegistryUpdated(address(newRegistry));

        vm.prank(owner);
        recorder.setAccessRegistry(address(newRegistry));
    }

    function test_SetAccessRegistry_RevertsOnZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("DR_ZeroAddress");
        recorder.setAccessRegistry(address(0));
    }

    function test_SetAccessRegistry_RevertsWhenCalledByNonOwner() public {
        AccessRegistry newRegistry = new AccessRegistry(owner);

        vm.prank(unauthorizedCaller);
        vm.expectRevert();
        recorder.setAccessRegistry(address(newRegistry));
    }

    // ============================================
    // CATEGORY 3: Event Recording - TextingRight
    // ============================================

    function test_RecordDistractionEventTextingRight_RecordsEvent() public {
        vm.prank(driver1);
        uint256 recordId = recorder.recordDistractionEventTextingRight();

        assertEq(recordId, 0);
        assertEq(recorder.getDriverRecordCount(driver1), 1);
    }

    function test_RecordDistractionEventTextingRight_EmitsEvent() public {
        uint256 currentTimestamp = block.timestamp;

        vm.expectEmit(true, true, true, true);
        emit DistractedDrivingRecorded(
            driver1, "ABC-123", IDistractionRecorder.EventClass.TextingRight, currentTimestamp, 0
        );

        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();
    }

    function test_RecordDistractionEventTextingRight_IncrementsRecordCount() public {
        vm.startPrank(driver1);
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventTextingRight();
        vm.stopPrank();

        assertEq(recorder.getDriverRecordCount(driver1), 3);
    }

    function test_RecordDistractionEventTextingRight_ReturnsRecordId() public {
        vm.startPrank(driver1);
        uint256 id0 = recorder.recordDistractionEventTextingRight();
        uint256 id1 = recorder.recordDistractionEventTextingRight();
        uint256 id2 = recorder.recordDistractionEventTextingRight();
        vm.stopPrank();

        assertEq(id0, 0);
        assertEq(id1, 1);
        assertEq(id2, 2);
    }

    function test_RecordDistractionEventTextingRight_UsesVehicleFromRegistry() public {
        vm.prank(driver1);
        uint256 recordId = recorder.recordDistractionEventTextingRight();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(records[0].vehicleNumber, "ABC-123");
    }

    function test_RecordDistractionEventTextingRight_UsesDefaultWhenNoVehicle() public {
        address driverNoVehicle = makeAddr("driverNoVehicle");

        vm.prank(driverNoVehicle);
        recorder.recordDistractionEventTextingRight();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driverNoVehicle, 0, 1);

        assertEq(records[0].vehicleNumber, "XXX-0000");
    }

    // ============================================
    // CATEGORY 4: Event Recording - All Types
    // ============================================

    function test_RecordDistractionEventPhoneRight_RecordsCorrectClass() public {
        vm.prank(driver1);
        recorder.recordDistractionEventPhoneRight();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.PhoneRight));
    }

    function test_RecordDistractionEventTextingLeft_RecordsCorrectClass() public {
        vm.prank(driver1);
        recorder.recordDistractionEventTextingLeft();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.TextingLeft));
    }

    function test_RecordDistractionEventPhoneLeft_RecordsCorrectClass() public {
        vm.prank(driver1);
        recorder.recordDistractionEventPhoneLeft();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.PhoneLeft));
    }

    function test_RecordDistractionEventRadio_RecordsCorrectClass() public {
        vm.prank(driver1);
        recorder.recordDistractionEventRadio();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.Radio));
    }

    function test_RecordDistractionEventDrinking_RecordsCorrectClass() public {
        vm.prank(driver1);
        recorder.recordDistractionEventDrinking();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.Drinking));
    }

    function test_RecordDistractionEventReachingBehind_RecordsCorrectClass() public {
        vm.prank(driver1);
        recorder.recordDistractionEventReachingBehind();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.ReachingBehind));
    }

    function test_RecordDistractionEventHairMakeup_RecordsCorrectClass() public {
        vm.prank(driver1);
        recorder.recordDistractionEventHairMakeup();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.HairMakeup));
    }

    function test_RecordDistractionEventTalkingToPassenger_RecordsCorrectClass() public {
        vm.prank(driver1);
        recorder.recordDistractionEventTalkingToPassenger();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.TalkingToPassenger));
    }

    // ============================================
    // CATEGORY 5: Event Recording - Edge Cases
    // ============================================

    function test_RecordEvent_MultipleEventsByDriver() public {
        vm.startPrank(driver1);
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventPhoneRight();
        recorder.recordDistractionEventDrinking();
        vm.stopPrank();

        assertEq(recorder.getDriverRecordCount(driver1), 3);

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 10);

        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.TextingRight));
        assertEq(uint256(records[1].eventClass), uint256(IDistractionRecorder.EventClass.PhoneRight));
        assertEq(uint256(records[2].eventClass), uint256(IDistractionRecorder.EventClass.Drinking));
    }

    function test_RecordEvent_DifferentDriversIndependentCounts() public {
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        vm.startPrank(driver2);
        recorder.recordDistractionEventPhoneRight();
        recorder.recordDistractionEventDrinking();
        vm.stopPrank();

        assertEq(recorder.getDriverRecordCount(driver1), 1);
        assertEq(recorder.getDriverRecordCount(driver2), 2);
    }

    function test_RecordEvent_TimestampIsBlockTimestamp() public {
        uint256 warpedTime = 1000000;
        vm.warp(warpedTime);

        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(records[0].timestamp, warpedTime);
    }

    function test_RecordEvent_SequentialRecordIds() public {
        uint256[] memory ids = _recordMultipleEvents(driver1, 5);

        for (uint256 i = 0; i < 5; i++) {
            assertEq(ids[i], i);
        }
    }

    function test_RecordEvent_VehicleNumberPersistence() public {
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        vm.prank(owner);
        registry.updateVehicleForDriver(driver1, "NEW-456");

        vm.prank(driver1);
        recorder.recordDistractionEventPhoneRight();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 10);

        assertEq(records[0].vehicleNumber, "ABC-123");
        assertEq(records[1].vehicleNumber, "NEW-456");
    }

    // ============================================
    // CATEGORY 6: Data Retrieval - Access Control
    // ============================================

    function test_GetDriverRecords_OnlyAccessRegistryCanCall() public {
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 10);

        assertEq(records.length, 1);
    }

    function test_GetDriverRecords_RevertsForUnauthorizedCaller() public {
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        vm.prank(unauthorizedCaller);
        vm.expectRevert("DR_UnauthorizedAccessRegistry");
        recorder.getDriverRecords(driver1, 0, 10);
    }

    function test_GetDriverRecordCount_PublicView() public {
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        uint256 count = recorder.getDriverRecordCount(driver1);
        assertEq(count, 1);
    }

    // ============================================
    // CATEGORY 7: Data Retrieval - Basic
    // ============================================

    function test_GetDriverRecords_ReturnsEmptyForNoRecords() public {
        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 10);

        assertEq(records.length, 0);
    }

    function test_GetDriverRecords_ReturnsSingleRecord() public {
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 10);

        assertEq(records.length, 1);
        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.TextingRight));
    }

    function test_GetDriverRecords_ReturnsAllRecordsWhenLimitExceeds() public {
        _recordMultipleEvents(driver1, 3);

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 100);

        assertEq(records.length, 3);
    }

    function test_GetDriverRecords_ReturnsCorrectRecordData() public {
        uint256 currentTime = block.timestamp;

        vm.prank(driver1);
        recorder.recordDistractionEventDrinking();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        _verifyRecordData(records[0], "ABC-123", IDistractionRecorder.EventClass.Drinking, currentTime);
    }

    // ============================================
    // CATEGORY 8: Pagination - Boundary Matrix
    // ============================================

    function test_Pagination_FirstPage() public {
        _recordMultipleEvents(driver1, 10);

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 3);

        assertEq(records.length, 3);
    }

    function test_Pagination_MiddlePage() public {
        _recordMultipleEvents(driver1, 10);

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 3, 3);

        assertEq(records.length, 3);
    }

    function test_Pagination_LastPage() public {
        _recordMultipleEvents(driver1, 10);

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 7, 3);

        assertEq(records.length, 3);
    }

    function test_Pagination_PartialLast() public {
        _recordMultipleEvents(driver1, 10);

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 8, 5);

        assertEq(records.length, 2);
    }

    function test_Pagination_OffsetEqualsCount() public {
        _recordMultipleEvents(driver1, 10);

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 10, 5);

        assertEq(records.length, 0);
    }

    function test_Pagination_OffsetExceedsCount() public {
        _recordMultipleEvents(driver1, 10);

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 15, 5);

        assertEq(records.length, 0);
    }

    function test_Pagination_LimitZero() public {
        _recordMultipleEvents(driver1, 10);

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 0);

        assertEq(records.length, 0);
    }

    function test_Pagination_LimitExceeds() public {
        _recordMultipleEvents(driver1, 10);

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 100);

        assertEq(records.length, 10);
    }

    function test_Pagination_SingleRecord() public {
        _recordMultipleEvents(driver1, 10);

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(records.length, 1);
    }

    function test_Pagination_EmptyState() public {
        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 10);

        assertEq(records.length, 0);
    }

    // ============================================
    // CATEGORY 9: Pagination - Data Consistency
    // ============================================

    function test_Pagination_DataConsistencyAcrossPages() public {
        _recordMultipleEvents(driver1, 10);

        vm.startPrank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory page1 = recorder.getDriverRecords(driver1, 0, 3);
        IDistractionRecorder.DistractionRecord[] memory page2 = recorder.getDriverRecords(driver1, 3, 3);
        IDistractionRecorder.DistractionRecord[] memory page3 = recorder.getDriverRecords(driver1, 6, 3);
        IDistractionRecorder.DistractionRecord[] memory page4 = recorder.getDriverRecords(driver1, 9, 3);
        vm.stopPrank();

        assertEq(page1.length, 3);
        assertEq(page2.length, 3);
        assertEq(page3.length, 3);
        assertEq(page4.length, 1);

        uint256 totalRecords = page1.length + page2.length + page3.length + page4.length;
        assertEq(totalRecords, 10);
    }

    function test_Pagination_RecordOrderPreserved() public {
        vm.startPrank(driver1);
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventPhoneRight();
        recorder.recordDistractionEventDrinking();
        vm.stopPrank();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 10);

        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.TextingRight));
        assertEq(uint256(records[1].eventClass), uint256(IDistractionRecorder.EventClass.PhoneRight));
        assertEq(uint256(records[2].eventClass), uint256(IDistractionRecorder.EventClass.Drinking));
    }

    function test_Pagination_NoGapsOrOverlaps() public {
        _recordMultipleEvents(driver1, 6);

        vm.startPrank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory page1 = recorder.getDriverRecords(driver1, 0, 2);
        IDistractionRecorder.DistractionRecord[] memory page2 = recorder.getDriverRecords(driver1, 2, 2);
        IDistractionRecorder.DistractionRecord[] memory page3 = recorder.getDriverRecords(driver1, 4, 2);
        vm.stopPrank();

        assertEq(page1.length, 2);
        assertEq(page2.length, 2);
        assertEq(page3.length, 2);
    }

    function test_Pagination_CorrectRecordContent() public {
        vm.warp(1000);
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        vm.warp(2000);
        vm.prank(driver1);
        recorder.recordDistractionEventPhoneRight();

        vm.warp(3000);
        vm.prank(driver1);
        recorder.recordDistractionEventDrinking();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 1, 1);

        assertEq(records.length, 1);
        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.PhoneRight));
        assertEq(records[0].timestamp, 2000);
        assertEq(records[0].vehicleNumber, "ABC-123");
    }

    // ============================================
    // CATEGORY 10: Storage Verification
    // ============================================

    function test_Storage_RecordsPersistCorrectly() public {
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(records.length, 1);
        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.TextingRight));
    }

    function test_Storage_RecordCountAccurate() public {
        _recordMultipleEvents(driver1, 7);

        assertEq(recorder.getDriverRecordCount(driver1), 7);
    }

    function test_Storage_VehicleNumberInRecord() public {
        vm.prank(driver2);
        recorder.recordDistractionEventDrinking();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver2, 0, 1);

        assertEq(records[0].vehicleNumber, "XYZ-789");
    }

    function test_Storage_EventClassInRecord() public {
        vm.prank(driver1);
        recorder.recordDistractionEventReachingBehind();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.ReachingBehind));
    }

    function test_Storage_TimestampInRecord() public {
        uint256 testTime = 5000000;
        vm.warp(testTime);

        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 1);

        assertEq(records[0].timestamp, testTime);
    }

    // ============================================
    // CATEGORY 11: Integration Tests
    // ============================================

    function test_Integration_FullRecordingAndRetrieval() public {
        vm.startPrank(driver1);
        recorder.recordDistractionEventTextingRight();
        recorder.recordDistractionEventPhoneRight();
        recorder.recordDistractionEventDrinking();
        vm.stopPrank();

        assertEq(recorder.getDriverRecordCount(driver1), 3);

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 10);

        assertEq(records.length, 3);
        assertEq(uint256(records[0].eventClass), uint256(IDistractionRecorder.EventClass.TextingRight));
        assertEq(uint256(records[1].eventClass), uint256(IDistractionRecorder.EventClass.PhoneRight));
        assertEq(uint256(records[2].eventClass), uint256(IDistractionRecorder.EventClass.Drinking));
    }

    function test_Integration_MultipleDriversIndependentRecords() public {
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        vm.startPrank(driver2);
        recorder.recordDistractionEventPhoneRight();
        recorder.recordDistractionEventDrinking();
        vm.stopPrank();

        assertEq(recorder.getDriverRecordCount(driver1), 1);
        assertEq(recorder.getDriverRecordCount(driver2), 2);

        vm.startPrank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records1 = recorder.getDriverRecords(driver1, 0, 10);
        IDistractionRecorder.DistractionRecord[] memory records2 = recorder.getDriverRecords(driver2, 0, 10);
        vm.stopPrank();

        assertEq(records1.length, 1);
        assertEq(records2.length, 2);
        assertEq(uint256(records1[0].eventClass), uint256(IDistractionRecorder.EventClass.TextingRight));
        assertEq(uint256(records2[0].eventClass), uint256(IDistractionRecorder.EventClass.PhoneRight));
    }

    function test_Integration_VehicleNumberUpdate() public {
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        assertEq(recorder.getDriverVehicleNumber(driver1), "ABC-123");

        vm.prank(owner);
        registry.updateVehicleForDriver(driver1, "NEW-999");

        vm.prank(driver1);
        recorder.recordDistractionEventPhoneRight();

        vm.prank(address(registry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 10);

        assertEq(records[0].vehicleNumber, "ABC-123");
        assertEq(records[1].vehicleNumber, "NEW-999");
    }

    function test_Integration_RegistryUpdate() public {
        vm.prank(driver1);
        recorder.recordDistractionEventTextingRight();

        AccessRegistry newRegistry = new AccessRegistry(owner);

        vm.prank(owner);
        recorder.setAccessRegistry(address(newRegistry));

        assertEq(address(recorder.accessRegistry()), address(newRegistry));

        vm.prank(address(newRegistry));
        IDistractionRecorder.DistractionRecord[] memory records = recorder.getDriverRecords(driver1, 0, 10);

        assertEq(records.length, 1);
    }
}
