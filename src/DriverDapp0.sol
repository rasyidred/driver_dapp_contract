// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract DriverDapp {
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

    enum StakeholderRole {
        None,
        LogisticsCompany,
        Police,
        TrafficAuthority,
        InsuranceCompany
    }

    struct DistractionRecord {
        uint256 timestamp;
        EventClass eventClass;
        uint256 blockNumber;
    }

    address public owner;
    mapping(address => StakeholderRole) public stakeholderRoles;
    mapping(address driver => mapping(uint256 recordId => DistractionRecord))
        public driverRecords;
    mapping(address driver => uint256 count) public driverRecordCounts;
    mapping(address driver => mapping(address stakeholder => bool isAuthorized))
        public authorizedStakeholders;

    address[] public allStakeholders;

    event DistractedDrivingRecorded(
        uint256 indexed recordId,
        address indexed driverAddress,
        EventClass indexed eventClass,
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

    modifier onlyAuthorized(address _driver) {
        if (msg.sender == _driver) {
            _;
            return;
        }
        require(
            stakeholderRoles[msg.sender] != StakeholderRole.None,
            "Unauthorized_Stakeholder"
        );
        require(authorizedStakeholders[_driver][msg.sender], "Access_Blocked");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function registerStakeholder(
        address _stakeholder,
        StakeholderRole _role
    ) external onlyOwner {
        require(_role != StakeholderRole.None, "Invalid role");
        stakeholderRoles[_stakeholder] = _role;
        allStakeholders.push(_stakeholder);
        emit StakeholderRegistered(_stakeholder, _role);
    }

    function revokeStakeholder(address _stakeholder) external onlyOwner {
        delete stakeholderRoles[_stakeholder];
        emit StakeholderRegistered(_stakeholder, StakeholderRole.None);
    }

    function addAuthorizedStakeholder(address _stakeholder) external {
        require(
            stakeholderRoles[_stakeholder] != StakeholderRole.None,
            "Not a registered stakeholder"
        );
        authorizedStakeholders[msg.sender][_stakeholder] = true;
        emit StakeholderAdded(_stakeholder);
    }

    function removeAuthorizedStakeholder(address _stakeholder) external {
        authorizedStakeholders[msg.sender][_stakeholder] = false;
        emit StakeholderRemoved(_stakeholder);
    }

    function recordDistractedDriving(
        EventClass _eventClass
    ) external returns (uint256) {
        uint256 recordId = driverRecordCounts[msg.sender];

        DistractionRecord memory newRecord = DistractionRecord({
            timestamp: block.timestamp,
            eventClass: _eventClass,
            blockNumber: block.number
        });

        driverRecords[msg.sender][recordId] = newRecord;

        emit DistractedDrivingRecorded(
            recordId,
            msg.sender,
            _eventClass,
            block.timestamp
        );

        driverRecordCounts[msg.sender]++;
        return recordId;
    }

    function getDistractedDrivingEvents(
        address _driver
    )
        external
        view
        onlyAuthorized(_driver)
        returns (DistractionRecord[] memory)
    {
        uint256 count = driverRecordCounts[_driver];
        DistractionRecord[] memory records = new DistractionRecord[](count);

        for (uint256 i = 0; i < count; i++) {
            records[i] = driverRecords[_driver][i];
        }

        return records;
    }

    // ---------------- Stakeholder Retrieval Functions ----------------

    function getLogisticsCompanies()
        external
        view
        onlyOwner
        returns (address[] memory)
    {
        return getStakeholdersByRole(StakeholderRole.LogisticsCompany);
    }

    function getPolice() external view onlyOwner returns (address[] memory) {
        return getStakeholdersByRole(StakeholderRole.Police);
    }

    function getTrafficAuthorities()
        external
        view
        onlyOwner
        returns (address[] memory)
    {
        return getStakeholdersByRole(StakeholderRole.TrafficAuthority);
    }

    function getInsuranceCompanies()
        external
        view
        onlyOwner
        returns (address[] memory)
    {
        return getStakeholdersByRole(StakeholderRole.InsuranceCompany);
    }

    // ---------------- Internal Helper Function ----------------

    function getStakeholdersByRole(
        StakeholderRole role
    ) internal view returns (address[] memory) {
        uint256 total = allStakeholders.length;
        uint256 count = 0;

        for (uint256 i = 0; i < total; i++) {
            if (stakeholderRoles[allStakeholders[i]] == role) {
                count++;
            }
        }

        address[] memory result = new address[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < total; i++) {
            if (stakeholderRoles[allStakeholders[i]] == role) {
                result[index] = allStakeholders[i];
                index++;
            }
        }

        return result;
    }
}
