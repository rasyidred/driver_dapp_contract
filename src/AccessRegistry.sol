// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessRegistry} from "./interfaces/IAccessRegistry.sol";
import {IDistractionRecorder} from "./interfaces/IDistractionRecorder.sol";

/// @title AccessRegistry
/// @notice Central registry for stakeholder roles, driver authorization, and vehicle management
/// @dev Implements role-based access control with driver-specific permissions and vehicle tracking
/// @dev Owner represents IT department of the area/nation
contract AccessRegistry is IAccessRegistry, Ownable {
    // State variables
    address public distractionRecorder;
    mapping(address => StakeholderRole) public stakeholderRoles;
    mapping(address driver => mapping(address stakeholder => bool isAuthorized))
        public authorizedStakeholders;
    mapping(address driver => string vehicleNumber) public driverVehicleNumbers;
    mapping(address driver => mapping(address stakeholder => bool isBlacklisted))
        public blacklist;

    // Events
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
    event StakeholderBlacklisted(
        address indexed driver,
        address indexed stakeholder
    );
    event BlacklistRemoved(address indexed driver, address indexed stakeholder);
    event DistractionRecorderUpdated(address indexed newRecorder);

    /// @notice Initialize the contract with an owner (IT department)
    /// @param _owner Address of the contract owner (IT department)
    constructor(address _owner) Ownable(_owner) {
        require(_owner != address(0), "AR_ZeroAddress");
    }

    /// @notice Register a stakeholder with a specific role (owner only)
    /// @dev Only IT department can register stakeholders
    /// @param _stakeholder Address of the stakeholder
    /// @param _role Role to assign to the stakeholder
    function registerStakeholder(
        address _stakeholder,
        StakeholderRole _role
    ) external onlyOwner {
        require(_stakeholder != address(0), "AR_ZeroAddress");
        require(_role != StakeholderRole.None, "AR_InvalidRole");

        stakeholderRoles[_stakeholder] = _role;
        emit StakeholderRegistered(_stakeholder, _role);
    }

    /// @notice Revoke a stakeholder's role (owner only)
    /// @dev Only IT department can revoke stakeholders
    /// @param _stakeholder Address of the stakeholder to revoke
    function revokeStakeholder(address _stakeholder) external onlyOwner {
        require(_stakeholder != address(0), "AR_ZeroAddress");
        require(
            stakeholderRoles[_stakeholder] != StakeholderRole.None,
            "AR_StakeholderNotRegistered"
        );

        stakeholderRoles[_stakeholder] = StakeholderRole.None;
        emit StakeholderRevoked(_stakeholder);
    }

    /// @notice Update vehicle number for a driver (owner only)
    /// @dev Only IT department can update vehicle information
    /// @param _driver Address of the driver
    /// @param _plateNo Vehicle plate number
    function updateVehicleForDriver(
        address _driver,
        string memory _plateNo
    ) external onlyOwner {
        require(_driver != address(0), "AR_ZeroAddress");
        driverVehicleNumbers[_driver] = _plateNo;
        emit VehicleNumberUpdated(_driver, _plateNo, block.timestamp);
    }

    /// @notice Set the DistractionRecorder contract address (owner only)
    /// @param _distractionRecorder Address of the DistractionRecorder contract
    function setDistractionRecorder(
        address _distractionRecorder
    ) external onlyOwner {
        require(_distractionRecorder != address(0), "AR_ZeroAddress");
        distractionRecorder = _distractionRecorder;
        emit DistractionRecorderUpdated(_distractionRecorder);
    }

    /// @notice Authorize a stakeholder to access caller's (driver's) records
    /// @param _stakeholder Address of the stakeholder to authorize
    function addAuthorizedStakeholder(address _stakeholder) external {
        require(_stakeholder != address(0), "AR_ZeroAddress");
        require(
            stakeholderRoles[_stakeholder] != StakeholderRole.None,
            "AR_StakeholderNotRegistered"
        );

        authorizedStakeholders[msg.sender][_stakeholder] = true;
        emit StakeholderAuthorized(msg.sender, _stakeholder);
    }

    /// @notice Remove authorization for a stakeholder to access caller's (driver's) records
    /// @param _stakeholder Address of the stakeholder to deauthorize
    function removeAuthorizedStakeholder(address _stakeholder) external {
        require(_stakeholder != address(0), "AR_ZeroAddress");
        require(
            stakeholderRoles[_stakeholder] != StakeholderRole.None,
            "AR_StakeholderNotRegistered"
        );

        authorizedStakeholders[msg.sender][_stakeholder] = false;
        emit StakeholderDeauthorized(msg.sender, _stakeholder);
    }

    /// @notice Check if a stakeholder is authorized by a driver
    /// @param _driver The driver's address
    /// @param _stakeholder The stakeholder's address
    /// @return bool True if stakeholder is authorized
    function isAuthorized(
        address _driver,
        address _stakeholder
    ) external view returns (bool) {
        return authorizedStakeholders[_driver][_stakeholder];
    }

    /// @notice Check if an address is a registered stakeholder
    /// @param _stakeholder The stakeholder's address
    /// @return bool True if stakeholder has a role
    function isRegisteredStakeholder(
        address _stakeholder
    ) external view returns (bool) {
        return stakeholderRoles[_stakeholder] != StakeholderRole.None;
    }

    /// @notice Get the role of a stakeholder
    /// @param _stakeholder The stakeholder's address
    /// @return StakeholderRole The role assigned to the stakeholder
    function getStakeholderRole(
        address _stakeholder
    ) external view returns (StakeholderRole) {
        return stakeholderRoles[_stakeholder];
    }

    /// @notice Get the vehicle number for a driver
    /// @param _driver The driver's address
    /// @return string The vehicle plate number
    function getDriverVehicleNumber(
        address _driver
    ) external view returns (string memory) {
        return driverVehicleNumbers[_driver];
    }

    /// @notice Blacklist a stakeholder from accessing driver records
    /// @param _stakeholder Address of the stakeholder to blacklist
    /// @dev Only the driver (msg.sender) can blacklist stakeholders from their own data
    function blacklistStakeholder(address _stakeholder) external {
        require(_stakeholder != address(0), "AR_ZeroAddress");
        blacklist[msg.sender][_stakeholder] = true;
        emit StakeholderBlacklisted(msg.sender, _stakeholder);
    }

    /// @notice Remove a stakeholder from the blacklist
    /// @param _stakeholder Address of the stakeholder to remove from blacklist
    /// @dev Only the driver (msg.sender) can manage their own blacklist
    function removeFromBlacklist(address _stakeholder) external {
        require(_stakeholder != address(0), "AR_ZeroAddress");
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

    /// @notice Gateway function to retrieve driver records with full authorization checks
    /// @dev Performs all access control checks before proxying to DistractionRecorder
    /// @param _driver Address of the driver whose records to retrieve
    /// @param _offset Starting index (0-based)
    /// @param _limit Maximum number of records to return
    /// @return vehicleNumberList Array of vehicle numbers for the requested range
    /// @return eventClassList Array of event classes for the requested range
    /// @return timestampList Array of timestamps for the requested range
    function getDriverRecords(
        address _driver,
        uint256 _offset,
        uint256 _limit
    )
        external
        view
        returns (
            string[] memory vehicleNumberList,
            IDistractionRecorder.EventClass[] memory eventClassList,
            uint256[] memory timestampList
        )
    {
        if (msg.sender != _driver) {
            require(
                distractionRecorder != address(0),
                "AR_DistractionRecorderNotSet"
            );

            // Check caller is a registered stakeholder
            require(
                this.isRegisteredStakeholder(msg.sender),
                "AR_UnauthorizedStakeholder"
            );

            // Check caller is authorized by the driver
            require(this.isAuthorized(_driver, msg.sender), "AR_AccessBlocked");

            // Check caller is not blacklisted by the driver
            require(
                !blacklist[_driver][msg.sender],
                "AR_BlacklistedStakeholder"
            );
        }

        // Proxy call to DistractionRecorder
        return
            IDistractionRecorder(distractionRecorder).getDriverRecords(
                _driver,
                _offset,
                _limit
            );
    }
}
