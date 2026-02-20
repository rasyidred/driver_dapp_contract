// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessRegistry} from "./interfaces/IAccessRegistry.sol";

/// @title DistractionRecorder
/// @notice Records and stores distracted driving events detected by AI monitoring systems
/// @dev Integrates with AccessRegistry for access control
contract DistractionRecorder is Ownable {
    /// @notice Types of distracted driving events
    enum EventClass {
        SafeDriving,
        TextingRight,
        PhoneRight,
        TextingLeft,
        PhoneLeft,
        Radio,
        Drinking,
        ReachingBehind,
        HairMakeup,
        TalkingToPassenger
    }

    /// @notice Structure for storing distraction event records
    struct DistractionRecord {
        string vehicleNumber;
        EventClass eventClass;
        uint256 timestamp;
    }

    // State variables
    IAccessRegistry public accessRegistry;

    mapping(address driver => mapping(uint256 recordId => DistractionRecord)) public driverRecords;
    mapping(address driver => uint256 count) public driverRecordCounts;

    // Events
    event DistractedDrivingRecorded(
        address indexed driver,
        string indexed vehicleNumber,
        EventClass indexed eventClass,
        uint256 timestamp,
        uint256 recordId
    );
    event AccessRegistryUpdated(address indexed newRegistry);

    /// @notice Initialize the contract with owner and registry address
    /// @param _initialOwner Address of the contract owner
    /// @param _accessRegistry Address of the AccessRegistry contract
    constructor(address _initialOwner, address _accessRegistry) Ownable(_initialOwner) {
        require(_initialOwner != address(0), "DR_ZeroAddress");
        require(_accessRegistry != address(0), "DR_ZeroAddress");
        accessRegistry = IAccessRegistry(_accessRegistry);
    }

    /// @notice Update the AccessRegistry contract address (owner only)
    /// @param _newRegistry Address of the new AccessRegistry contract
    function setAccessRegistry(address _newRegistry) external onlyOwner {
        require(_newRegistry != address(0), "DR_ZeroAddress");
        accessRegistry = IAccessRegistry(_newRegistry);
        emit AccessRegistryUpdated(_newRegistry);
    }

    /// @notice Modifier to restrict function access to AccessRegistry contract only
    modifier onlyAccessRegistry() {
        require(msg.sender == address(accessRegistry), "DR_UnauthorizedCaller");
        _;
    }

    /// @notice Record a TextingRight distraction event
    /// @return recordId The ID of the created record
    function recordDistractionEventTextingRight() external returns (uint256) {
        return _recordEvent(EventClass.TextingRight);
    }

    /// @notice Record a PhoneRight distraction event
    /// @return recordId The ID of the created record
    function recordDistractionEventPhoneRight() external returns (uint256) {
        return _recordEvent(EventClass.PhoneRight);
    }

    /// @notice Record a TextingLeft distraction event
    /// @return recordId The ID of the created record
    function recordDistractionEventTextingLeft() external returns (uint256) {
        return _recordEvent(EventClass.TextingLeft);
    }

    /// @notice Record a PhoneLeft distraction event
    /// @return recordId The ID of the created record
    function recordDistractionEventPhoneLeft() external returns (uint256) {
        return _recordEvent(EventClass.PhoneLeft);
    }

    /// @notice Record a Radio distraction event
    /// @return recordId The ID of the created record
    function recordDistractionEventRadio() external returns (uint256) {
        return _recordEvent(EventClass.Radio);
    }

    /// @notice Record a Drinking distraction event
    /// @return recordId The ID of the created record
    function recordDistractionEventDrinking() external returns (uint256) {
        return _recordEvent(EventClass.Drinking);
    }

    /// @notice Record a ReachingBehind distraction event
    /// @return recordId The ID of the created record
    function recordDistractionEventReachingBehind() external returns (uint256) {
        return _recordEvent(EventClass.ReachingBehind);
    }

    /// @notice Record a HairMakeup distraction event
    /// @return recordId The ID of the created record
    function recordDistractionEventHairMakeup() external returns (uint256) {
        return _recordEvent(EventClass.HairMakeup);
    }

    /// @notice Record a TalkingToPassenger distraction event
    /// @return recordId The ID of the created record
    function recordDistractionEventTalkingToPassenger() external returns (uint256) {
        return _recordEvent(EventClass.TalkingToPassenger);
    }

    /// @notice Get paginated record data for a specific driver
    /// @dev Only callable by AccessRegistry contract - authorization checks performed there
    /// @dev Useful for querying large datasets, especially in Remix or limited gas contexts
    /// @param _driver Address of the driver
    /// @param _offset Starting index (0-based)
    /// @param _limit Maximum number of records to return
    /// @return records Array of driver distraction records
    function getDriverRecords(address _driver, uint256 _offset, uint256 _limit)
        external
        view
        returns (DistractionRecord[] memory records)
    {
        require(address(accessRegistry) != address(0), "DR_RegistryNotSet");

        // Check caller is a registered Access Registry
        require(msg.sender == address(accessRegistry), "DR_UnauthorizedAccessRegistry");

        uint256 count = driverRecordCounts[_driver];

        // Calculate the actual end index
        uint256 end = _offset + _limit;
        if (end > count) {
            end = count;
        }

        // Calculate result size
        uint256 resultSize = end > _offset ? end - _offset : 0;

        // Initialize the records array with correct size
        records = new DistractionRecord[](resultSize);

        // Populate the records array
        for (uint256 i = 0; i < resultSize; i++) {
            uint256 recordIndex = _offset + i;
            records[i] = driverRecords[_driver][recordIndex];
        }

        return records;
    }

    /// @notice Internal function to record distraction events
    /// @param _eventClass Type of distraction event
    /// @return recordId The ID of the created record
    function _recordEvent(EventClass _eventClass) internal returns (uint256) {
        require(address(accessRegistry) != address(0), "DR_RegistryNotSet");

        uint256 recordId = driverRecordCounts[msg.sender];

        // Get vehicle plate number from AccessRegistry
        string memory plateNo = accessRegistry.getDriverVehicleNumber(msg.sender);

        if (bytes(plateNo).length == 0) {
            plateNo = "XXX-0000";
        }

        DistractionRecord memory newRecord =
            DistractionRecord({vehicleNumber: plateNo, eventClass: _eventClass, timestamp: block.timestamp});

        // Effects: Save new record
        driverRecords[msg.sender][recordId] = newRecord;

        // Effects: Update the record count
        driverRecordCounts[msg.sender]++;

        // Interactions: Emit event
        emit DistractedDrivingRecorded(msg.sender, plateNo, _eventClass, block.timestamp, recordId);

        return recordId;
    }
}
