// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

interface IDistractionRecorder {
    // =============================================================
    //                           TYPES
    // =============================================================

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

    struct DistractionRecord {
        string vehicleNumber;
        EventClass eventClass;
        uint256 timestamp;
    }

    // =============================================================
    //                       FUNCTIONS
    // =============================================================

    /// @notice Update the AccessRegistry contract address
    function setAccessRegistry(address _newRegistry) external;

    /// @notice Get total count of records for a driver (for pagination metadata)
    function getDriverRecordCount(address _driver) external view returns (uint256);

    /// @notice Get paginated record data for a specific driver
    function getDriverRecords(address _driver, uint256 _offset, uint256 _limit)
        external
        view
        returns (DistractionRecord[] memory records);

    // ------------------- Recording Wrappers -------------------
    // These specific functions correspond to the "Algorithm 2" logic

    function recordDistractionEventTextingRight() external returns (uint256);

    function recordDistractionEventPhoneRight() external returns (uint256);

    function recordDistractionEventTextingLeft() external returns (uint256);

    function recordDistractionEventPhoneLeft() external returns (uint256);

    function recordDistractionEventRadio() external returns (uint256);

    function recordDistractionEventDrinking() external returns (uint256);

    function recordDistractionEventReachingBehind() external returns (uint256);

    function recordDistractionEventHairMakeup() external returns (uint256);

    function recordDistractionEventTalkingToPassenger() external returns (uint256);
}
