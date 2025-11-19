// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IDistractionRecorder
/// @notice Interface for accessing driver distraction records
/// @dev Used by AccessRegistry to retrieve driver records
interface IDistractionRecorder {
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

    /// @notice Get paginated record data for a specific driver
    /// @param _driver Address of the driver
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
            EventClass[] memory eventClassList,
            uint256[] memory timestampList
        );
}
