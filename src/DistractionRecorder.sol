// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessRegistry} from "./interfaces/IAccessRegistry.sol";

/// @title DistractionRecorder
/// @notice Records and stores distracted driving events detected by AI monitoring systems
/// @dev Integrates with AccessRegistry for access control
contract DistractionRecorder is Ownable {
    // Custom errors
    error ZeroAddress();
    error UnauthorizedStakeholder();
    error AccessBlocked();
    error RegistryNotSet();
    error BlacklistedStakeholder();

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
        address driver;
        string vehicleNumber;
        EventClass eventClass;
        uint256 timestamp;
    }

    // State variables
    IAccessRegistry public accessRegistry;

    mapping(address driver => mapping(uint256 recordId => DistractionRecord))
        public driverRecords;
    mapping(address driver => uint256 count) public driverRecordCounts;
    mapping(address driver => mapping(address stakeholder => bool isBlacklisted))
        public blacklist;

    // Events
    event DistractedDrivingRecorded(
        address indexed driver,
        string indexed vehicleNumber,
        EventClass indexed eventClass,
        uint256 timestamp,
        uint256 recordId
    );
    event AccessRegistryUpdated(address indexed newRegistry);
    event StakeholderBlacklisted(
        address indexed driver,
        address indexed stakeholder
    );
    event BlacklistRemoved(address indexed driver, address indexed stakeholder);

    /// @notice Initialize the contract with owner and registry address
    /// @param _owner Address of the contract owner
    /// @param _accessRegistry Address of the AccessRegistry contract
    constructor(address _owner, address _accessRegistry) Ownable(_owner) {
        if (_owner == address(0)) revert ZeroAddress();
        if (_accessRegistry == address(0)) revert ZeroAddress();
        accessRegistry = IAccessRegistry(_accessRegistry);
    }

    /// @notice Update the AccessRegistry contract address (owner only)
    /// @param _newRegistry Address of the new AccessRegistry contract
    function setAccessRegistry(address _newRegistry) external onlyOwner {
        if (_newRegistry == address(0)) revert ZeroAddress();
        accessRegistry = IAccessRegistry(_newRegistry);
        emit AccessRegistryUpdated(_newRegistry);
    }

    /// @notice Modifier to check if caller is not blacklisted by the driver
    /// @param _driver Address of the driver whose blacklist to check
    modifier notBlacklisted(address _driver) {
        if (blacklist[_driver][msg.sender]) revert BlacklistedStakeholder();
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
    function recordDistractionEventTalkingToPassenger()
        external
        returns (uint256)
    {
        return _recordEvent(EventClass.TalkingToPassenger);
    }

    /// @notice Blacklist a stakeholder from accessing driver records
    /// @param _stakeholder Address of the stakeholder to blacklist
    /// @dev Only the driver (msg.sender) can blacklist stakeholders from their own data
    function blacklistStakeholder(address _stakeholder) external {
        if (_stakeholder == address(0)) revert ZeroAddress();
        blacklist[msg.sender][_stakeholder] = true;
        emit StakeholderBlacklisted(msg.sender, _stakeholder);
    }

    /// @notice Remove a stakeholder from the blacklist
    /// @param _stakeholder Address of the stakeholder to remove from blacklist
    /// @dev Only the driver (msg.sender) can manage their own blacklist
    function removeFromBlacklist(address _stakeholder) external {
        if (_stakeholder == address(0)) revert ZeroAddress();
        blacklist[msg.sender][_stakeholder] = false;
        emit BlacklistRemoved(msg.sender, _stakeholder);
    }

    /// @notice Check if a stakeholder is blacklisted by a driver
    /// @param _driver Address of the driver
    /// @param _stakeholder Address of the stakeholder to check
    /// @return bool True if stakeholder is blacklisted, false otherwise
    function isBlacklisted(
        address _driver,
        address _stakeholder
    ) external view returns (bool) {
        return blacklist[_driver][_stakeholder];
    }

    /// @notice Get all record data for a specific driver (authorization required)
    /// @param _driver Address of the driver
    /// @return vehicleNumberList Array of vehicle numbers for each record
    /// @return eventClassList Array of event classes for each record
    /// @return timestampList Array of timestamps for each record
    function getDriverRecords(
        address _driver
    )
        external
        view
        notBlacklisted(_driver)
        returns (
            string[] memory vehicleNumberList,
            EventClass[] memory eventClassList,
            uint256[] memory timestampList
        )
    {
        if (address(accessRegistry) == address(0)) revert RegistryNotSet();

        // Check caller is a registered stakeholder
        if (!accessRegistry.isRegisteredStakeholder(msg.sender))
            revert UnauthorizedStakeholder();

        // Check caller is authorized by the driver
        if (!accessRegistry.isAuthorized(_driver, msg.sender))
            revert AccessBlocked();

        uint256 count = driverRecordCounts[_driver];
        vehicleNumberList = new string[](count);
        eventClassList = new EventClass[](count);
        timestampList = new uint256[](count);

        for (uint256 i = 0; i < count; i++) {
            vehicleNumberList[i] = driverRecords[_driver][i].vehicleNumber;
            eventClassList[i] = driverRecords[_driver][i].eventClass;
            timestampList[i] = driverRecords[_driver][i].timestamp;
        }

        return (vehicleNumberList, eventClassList, timestampList);
    }

    /// @notice Internal function to record distraction events
    /// @param _eventClass Type of distraction event
    /// @return recordId The ID of the created record
    function _recordEvent(EventClass _eventClass) internal returns (uint256) {
        if (address(accessRegistry) == address(0)) revert RegistryNotSet();

        uint256 recordId = driverRecordCounts[msg.sender];

        // Get vehicle plate number from AccessRegistry
        string memory plateNo = accessRegistry.getDriverVehicleNumber(
            msg.sender
        );

        DistractionRecord memory newRecord = DistractionRecord({
            timestamp: block.timestamp,
            driver: msg.sender,
            vehicleNumber: plateNo,
            eventClass: _eventClass
        });

        // Effects: Save new record
        driverRecords[msg.sender][recordId] = newRecord;

        // Effects: Update the record count
        driverRecordCounts[msg.sender]++;

        // Interactions: Emit event
        emit DistractedDrivingRecorded(
            msg.sender,
            plateNo,
            _eventClass,
            block.timestamp,
            recordId
        );

        return recordId;
    }
}
