// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

// Import needed to reference the DistractionRecord struct in return values
import {IDistractionRecorder} from "./IDistractionRecorder.sol";

interface IAccessRegistry {
    // =============================================================
    //                           TYPES
    // =============================================================

    enum StakeholderRole {
        None,
        InsuranceCompany,
        LawEnforcement,
        FleetManager,
        RegulatoryBody
    }

    // =============================================================
    //                    ADMIN FUNCTIONS
    // =============================================================

    function registerStakeholder(address _stakeholder, StakeholderRole _role) external;
    function revokeStakeholder(address _stakeholder) external;
    function updateVehicleForDriver(address _driver, string memory _plateNo) external;
    function setDistractionRecorder(address _distractionRecorder) external;

    // =============================================================
    //                  DRIVER FUNCTIONS
    // =============================================================

    function addAuthorizedStakeholder(address _stakeholder) external;
    function removeAuthorizedStakeholder(address _stakeholder) external;

    // =============================================================
    //                        VIEWS
    // =============================================================

    function isAuthorized(address _driver, address _stakeholder) external view returns (bool);
    function isRegisteredStakeholder(address _stakeholder) external view returns (bool);
    function getStakeholderRole(address _stakeholder) external view returns (StakeholderRole);
    function getDriverVehicleNumber(address _driver) external view returns (string memory);

    // =============================================================
    //                    DATA GATEWAY
    // =============================================================

    /// @notice Gateway function to retrieve driver records AND total count
    /// @return records The array of distraction events
    /// @return totalCount The total number of records (metadata for frontend pagination)
    function getDistractedDrivingEvents(address _driver, uint256 _offset, uint256 _limit)
        external
        view
        returns (IDistractionRecorder.DistractionRecord[] memory records, uint256 totalCount);
}
