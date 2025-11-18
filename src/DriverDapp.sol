// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DrivingMonitor {
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

    enum StakeholderRole {
        None,
        LogisticsCompany,
        Police,
        TrafficAuthority,
        InsuranceCompany
    }

    struct DistractionRecord {
        address vehicleAddress;
        EventClass eventClass;
        uint256 timestamp;
    }

    mapping(address => StakeholderRole) public stakeholderRoles;
    mapping(address vehicle => mapping(uint256 recordId => DistractionRecord))
        public vehicleRecords;
    mapping(address vehicle => uint256 count) public vehicleRecordCounts;
    mapping(address vehicle => mapping(address stakeholder => bool isAuthorized))
        public authorizedStakeholders;

    event DistractedDrivingRecorded(
        uint256 indexed recordId,
        address indexed vehicleAddress,
        EventClass indexed eventClass,
        uint256 confidence,
        uint256 timestamp
    );

    event StakeholderRegistered(
        address indexed stakeholder,
        StakeholderRole indexed role
    );
    event StakeholderAdded(address indexed stakeholder);
    event StakeholderRemoved(address indexed stakeholder);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyAuthorizedStakeholder() {
        require(
            stakeholderRoles[msg.sender] != StakeholderRole.None,
            "Unauthorized_Stakeholder"
        );

        _;
    }

    /// @dev msg.sender is the authority
    modifier onlyWhiteListedAuthority(address _vehicleAddress) {
        require(
            authorizedStakeholders[_vehicleAddress][msg.sender] == true,
            "Access_Blocked"
        );
        _;
    }

    constructor(address _owner) Ownable(_owner) {}

    function registerStakeholder(
        address _stakeholder,
        StakeholderRole _role
    ) external onlyOwner {
        require(_role != StakeholderRole.None, "Invalid role");
        stakeholderRoles[_stakeholder] = _role;
        emit StakeholderRegistered(_stakeholder, _role);
    }

    function addAuthorizedStakeholder(address _stakeholder) external {
        require(
            stakeholderRoles[_stakeholder] != StakeholderRole.None,
            "Invalid_Stakeholder"
        );
        authorizedStakeholders[msg.sender][_stakeholder] = true;
    }

    function removeAuthorizedStakeholder(address _stakeholder) external {
        require(
            stakeholderRoles[_stakeholder] != StakeholderRole.None,
            "Invalid_Stakeholder"
        );
        authorizedStakeholders[msg.sender][_stakeholder] = false;
    }

    function recordDistractionEvent(

    ) external returns (uint256) {
        require(
            registeredVehicles[msg.sender] == true,
            "Not a registered vehicle"
        );
        uint recordId = vehicleRecordCounts[msg.sender];

        DistractionRecord memory newRecord = DistractionRecord({
            timestamp: block.timestamp,
            vehicleAddress: msg.sender,
            eventClass: _eventClass
        });

        // Save new record
        vehicleRecords[msg.sender][recordId] = newRecord;

        emit DistractedDrivingRecorded(
            recordId,
            msg.sender,
            _eventClass,
            _confidence,
            block.timestamp
        );

        // Update the record count +1
        vehicleRecordCounts[msg.sender]++;

        return recordId;
    }

    function getVehicleRecords(
        address _vehicleAddress
    )
        external
        view
        onlyAuthorizedStakeholder
        onlyWhiteListedAuthority(_vehicleAddress)
        returns (uint256[] memory)
    {
        uint256 count = vehicleRecordCounts[_vehicleAddress];

        uint256[] memory vehicleRecordIds = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < count; i++) {
            vehicleRecordIds[index] = i;
        }

        return vehicleRecordIds;
    }
}
