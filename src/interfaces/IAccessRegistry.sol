// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IAccessRegistry
/// @notice Interface for access control, stakeholder management, and driver information
/// @dev Used by DistractionRecorder to verify access permissions
interface IAccessRegistry {
    enum StakeholderRole {
        None,
        LogisticsCompany,
        Police,
        TrafficAuthority,
        InsuranceCompany
    }

    /// @notice Check if a stakeholder is authorized by a driver to access their records
    /// @param _driver The driver's address
    /// @param _stakeholder The stakeholder's address
    /// @return bool True if stakeholder is authorized by driver
    function isAuthorized(
        address _driver,
        address _stakeholder
    ) external view returns (bool);

    /// @notice Check if an address is a registered stakeholder
    /// @param _stakeholder The stakeholder's address
    /// @return bool True if stakeholder has a role assigned
    function isRegisteredStakeholder(
        address _stakeholder
    ) external view returns (bool);

    /// @notice Get the role of a stakeholder
    /// @param _stakeholder The stakeholder's address
    /// @return StakeholderRole The role assigned to the stakeholder
    function getStakeholderRole(
        address _stakeholder
    ) external view returns (StakeholderRole);

    /// @notice Get the vehicle number for a driver
    /// @param _driver The driver's address
    /// @return string The vehicle plate number
    function getDriverVehicleNumber(
        address _driver
    ) external view returns (string memory);
}
