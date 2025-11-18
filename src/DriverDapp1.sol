// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title DrivingMonitor
/// @notice Decentralized registry for recording verified distracted-driving incidents
/// @author rasyidred
/// @dev Provides a blockchain-based data layer for AI-assisted driving behavior monitoring.
///      Integrates with off-chain AI classification modules, edge devices, and stakeholder DApps.
///      Designed for multi-stakeholder access (Logistics, Police, Traffic Authority, Insurance).
contract DrivingMonitor is Ownable {
    /// @notice Roles of stakeholders in the ecosystem
    /// @dev Used to enforce access control and classification of node roles
    enum StakeholderRole {
        None,
        LogisticsCompany,
        Police,
        TrafficAuthority,
        InsuranceCompany
    }

    /// @notice Categories of distracted driving behaviors detected by AI
    /// @dev Each category maps to a class label in the CNN classifier
    enum EventClass {
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

    /// @notice Structure to store distracted driving record
    /// @dev timestamp = Unix time, eventClass = detected class, blockNumber = block of submission
    struct DistractionRecord {
        uint256 timestamp;
        EventClass eventClass;
        uint256 blockNumber;
    }

    /// @notice Emitted when a new distracted-driving event is recorded
    /// @param driver Address of the driver whose record was submitted
    /// @param recordId Sequential index of the driver’s record
    /// @param timestamp Timestamp of the event (provided by AI system)
    /// @param eventClass Type of distracted driving behavior detected
    /// @param reporter Address that submitted the report (could be stakeholder or device)
    event DistractedDrivingRecorded(
        address indexed driver,
        uint256 indexed recordId,
        uint256 timestamp,
        EventClass eventClass,
        address reporter
    );

    /// @notice Emitted when a stakeholder is registered by the owner
    /// @param stakeholder Address of the stakeholder
    /// @param role Role assigned to the stakeholder
    event StakeholderRegistered(
        address indexed stakeholder,
        StakeholderRole indexed role
    );

    /// @notice Emitted when a driver authorizes a stakeholder to access their data
    /// @param stakeholder Address of the stakeholder granted access
    event StakeholderAdded(address indexed stakeholder);

    /// @notice Emitted when a driver revokes access from a stakeholder
    /// @param stakeholder Address of the stakeholder revoked
    event StakeholderRemoved(address indexed stakeholder);

    mapping(address => StakeholderRole) public stakeholderRoles;
    mapping(address => DistractionRecord[]) private driverRecords;
    mapping(address => mapping(address => bool)) public authorizedStakeholders;
    address[] public allStakeholders;

    constructor(address _owner) Ownable(_owner) {}

    /// @notice Register a stakeholder organization with a specific role
    /// @dev Only owner can register. Enables stakeholder participation and recording.
    /// @param _stakeholder Address of the stakeholder organization
    /// @param _role Assigned StakeholderRole enum value
    function registerStakeholder(
        address _stakeholder,
        StakeholderRole _role
    ) external onlyOwner {
        stakeholderRoles[_stakeholder] = _role;
        allStakeholders.push(_stakeholder);
        emit StakeholderRegistered(_stakeholder, _role);
    }

    /// @notice Revoke stakeholder role
    /// @dev Removes the stakeholder from registry
    /// @param _stakeholder Address to revoke
    function revokeStakeholder(address _stakeholder) external onlyOwner {
        stakeholderRoles[_stakeholder] = StakeholderRole.None;
        emit StakeholderRegistered(_stakeholder, StakeholderRole.None);
    }

    /// @notice Authorize stakeholder to view driver’s records
    /// @dev Called by driver; grants access for given stakeholder address
    /// @param _stakeholder Stakeholder address to authorize
    function addAuthorizedStakeholder(address _stakeholder) external {
        authorizedStakeholders[msg.sender][_stakeholder] = true;
        emit StakeholderAdded(_stakeholder);
    }

    /// @notice Revoke previously granted stakeholder access
    /// @dev Called by driver
    /// @param _stakeholder Stakeholder address to revoke
    function removeAuthorizedStakeholder(address _stakeholder) external {
        authorizedStakeholders[msg.sender][_stakeholder] = false;
        emit StakeholderRemoved(_stakeholder);
    }

    /// @notice Record a distracted-driving incident
    /// @dev Usually called by AI/edge device through stakeholder node using Web3 interface
    /// @param _driver Driver address to associate record with
    /// @param _timestamp Event timestamp captured by AI module
    /// @param _eventClass Event class label
    /// @return recordId Sequential ID of the new record
    function recordDistractedDriving(
        address _driver,
        uint256 _timestamp,
        EventClass _eventClass
    ) external returns (uint256 recordId) {
        DistractionRecord memory newRecord = DistractionRecord({
            timestamp: _timestamp,
            eventClass: _eventClass,
            blockNumber: block.number
        });

        driverRecords[_driver].push(newRecord);
        recordId = driverRecords[_driver].length - 1;

        emit DistractedDrivingRecorded(
            _driver,
            recordId,
            _timestamp,
            _eventClass,
            msg.sender
        );
    }

    /// @notice Retrieve all distracted-driving records of a driver
    /// @param _driver Address of the driver
    /// @return Array of DistractionRecord structs
    function getDistractedDrivingEvents(
        address _driver
    ) external view returns (DistractionRecord[] memory) {
        require(
            msg.sender == _driver ||
                authorizedStakeholders[_driver][msg.sender],
            "Unauthorized_Stakeholder"
        );
        return driverRecords[_driver];
    }

    /// @notice Get all stakeholder addresses by assigned role
    /// @dev Iterates allStakeholders list for matching role
    /// @param _role Role to query
    /// @return Array of stakeholder addresses matching role
    function getStakeholdersByRole(
        StakeholderRole _role
    ) external view returns (address[] memory) {
        uint256 count = 0;
        uint256 stakeholderNumbers = allStakeholders.length;
        for (uint256 i = 0; i < stakeholderNumbers; i++) {
            if (stakeholderRoles[allStakeholders[i]] == _role) count++;
        }

        address[] memory result = new address[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < stakeholderNumbers; i++) {
            if (stakeholderRoles[allStakeholders[i]] == _role) {
                result[idx++] = allStakeholders[i];
            }
        }
        return result;
    }
}
