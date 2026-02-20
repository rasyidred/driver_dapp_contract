// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessRegistry} from "./interfaces/IAccessRegistry.sol";
import {IDistractionRecorder} from "./interfaces/IDistractionRecorder.sol";

/// @title AccessRegistry
/// @notice Central registry for stakeholder roles, driver authorization, and vehicle management
/// @dev Implements Role-Based Access Control (RBAC) and acts as the secure Gateway to DistractionRecorder
/// @dev Follows a "Zero Trust" model: Stakeholders are denied access by default unless authorized.
contract AccessRegistry is IAccessRegistry, Ownable {
    // =============================================================
    //                           STATE
    // =============================================================

    address public distractionRecorder;

    // Maps a generic address to a specific Role (e.g., Insurance, Police)
    mapping(address => StakeholderRole) public stakeholderRoles;

    // driver => stakeholder => isAuthorized
    // This is the SINGLE source of truth for access permission
    mapping(address => mapping(address => bool)) public authorizedStakeholders;

    // driver => vehicleNumber
    mapping(address => string) public driverVehicleNumbers;

    // =============================================================
    //                           EVENTS
    // =============================================================

    event StakeholderRegistered(
        address indexed stakeholder,
        StakeholderRole indexed role
    );
    event StakeholderRevoked(address indexed stakeholder);
    event StakeholderAuthorized(
        address indexed driver,
        address indexed stakeholder
    );
    event StakeholderDeauthorized(
        address indexed driver,
        address indexed stakeholder
    );
    event VehicleNumberUpdated(
        address indexed driver,
        string indexed vehicleNumber,
        uint256 indexed timestamp
    );
    event DistractionRecorderUpdated(address indexed newRecorder);

    // =============================================================
    //                      INITIALIZATION
    // =============================================================

    /// @notice Initialize the contract with an owner (IT department)
    /// @param _initialOwner Address of the contract owner
    constructor(address _initialOwner) Ownable(_initialOwner) {
        require(_initialOwner != address(0), "AR_ZeroAddress");
    }

    // =============================================================
    //                    ADMIN FUNCTIONS (IT DEPT)
    // =============================================================

    /// @notice Register a stakeholder with a specific role
    function registerStakeholder(
        address _stakeholder,
        StakeholderRole _role
    ) external onlyOwner {
        require(_stakeholder != address(0), "AR_ZeroAddress");
        require(_role != StakeholderRole.None, "AR_InvalidRole");

        stakeholderRoles[_stakeholder] = _role;
        emit StakeholderRegistered(_stakeholder, _role);
    }

    /// @notice Revoke a stakeholder's role
    function revokeStakeholder(address _stakeholder) external onlyOwner {
        require(_stakeholder != address(0), "AR_ZeroAddress");
        require(
            stakeholderRoles[_stakeholder] != StakeholderRole.None,
            "AR_NotRegistered"
        );

        stakeholderRoles[_stakeholder] = StakeholderRole.None;
        emit StakeholderRevoked(_stakeholder);
    }

    /// @notice Update vehicle number for a driver
    function updateVehicleForDriver(
        address _driver,
        string memory _plateNo
    ) external onlyOwner {
        require(_driver != address(0), "AR_ZeroAddress");
        driverVehicleNumbers[_driver] = _plateNo;
        emit VehicleNumberUpdated(_driver, _plateNo, block.timestamp);
    }

    /// @notice Set the DistractionRecorder contract address
    function setDistractionRecorder(
        address _distractionRecorder
    ) external onlyOwner {
        require(_distractionRecorder != address(0), "AR_ZeroAddress");
        distractionRecorder = _distractionRecorder;
        emit DistractionRecorderUpdated(_distractionRecorder);
    }

    // =============================================================
    //                  DRIVER CONTROLLED FUNCTIONS
    // =============================================================

    /// @notice Authorize a stakeholder to access records
    /// @dev Driver can only authorize entities that are already registered by IT Dept
    function addAuthorizedStakeholder(address _stakeholder) external {
        require(_stakeholder != address(0), "AR_ZeroAddress");
        require(
            stakeholderRoles[_stakeholder] != StakeholderRole.None,
            "AR_UnknownEntity"
        );

        authorizedStakeholders[msg.sender][_stakeholder] = true;
        emit StakeholderAuthorized(msg.sender, _stakeholder);
    }

    /// @notice Remove authorization for a stakeholder
    /// @dev Removes access immediately. No separate blacklist needed.
    function removeAuthorizedStakeholder(address _stakeholder) external {
        require(_stakeholder != address(0), "AR_ZeroAddress");

        authorizedStakeholders[msg.sender][_stakeholder] = false;
        emit StakeholderDeauthorized(msg.sender, _stakeholder);
    }

    // =============================================================
    //                        VIEW FUNCTIONS
    // =============================================================

    function isAuthorized(
        address _driver,
        address _stakeholder
    ) external view returns (bool) {
        return authorizedStakeholders[_driver][_stakeholder];
    }

    function isRegisteredStakeholder(
        address _stakeholder
    ) external view returns (bool) {
        return stakeholderRoles[_stakeholder] != StakeholderRole.None;
    }

    function getStakeholderRole(
        address _stakeholder
    ) external view returns (StakeholderRole) {
        return stakeholderRoles[_stakeholder];
    }

    function getDriverVehicleNumber(
        address _driver
    ) external view returns (string memory) {
        return driverVehicleNumbers[_driver];
    }

    // =============================================================
    //                DATA GATEWAY (CORE LOGIC)
    // =============================================================

    /// @notice Gateway function to retrieve driver records AND total count with full auth checks
    /// @dev Acts as an API Gateway: Aggregates Data + Metadata (Count) for the frontend
    /// @param _driver Address of the driver whose records to retrieve
    /// @param _offset Starting index (0-based)
    /// @param _limit Maximum number of records to return
    /// @return records Array of DistractionRecord structs
    /// @return totalCount The total number of records available (for pagination)
    function getDistractedDrivingEvents(
        address _driver,
        uint256 _offset,
        uint256 _limit
    )
        external
        view
        returns (
            IDistractionRecorder.DistractionRecord[] memory records,
            uint256 totalCount
        )
    {
        require(distractionRecorder != address(0), "AR_RecorderNotSet");

        // 1. Access Control Logic
        // If the caller is NOT the driver, we must perform security checks
        if (msg.sender != _driver) {
            // Check A: Is the caller a recognized entity (Insurance, Police, etc.)?
            require(
                stakeholderRoles[msg.sender] != StakeholderRole.None,
                "AR_UnauthorizedStakeholder"
            );

            // Check B: Has the driver explicitly authorized this specific entity?
            require(
                authorizedStakeholders[_driver][msg.sender],
                "AR_AccessDenied"
            );
        }

        // 2. Fetch Data (Proxy to DistractionRecorder)
        records = IDistractionRecorder(distractionRecorder).getDriverRecords(
            _driver,
            _offset,
            _limit
        );

        // 3. Fetch Metadata (Total Count)
        // This ensures the frontend knows the total pages available without extra RPC calls
        totalCount = IDistractionRecorder(distractionRecorder)
            .getDriverRecordCount(_driver);

        return (records, totalCount);
    }
}
