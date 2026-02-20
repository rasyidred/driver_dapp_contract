// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IDistractionRecorder} from "../../src/interfaces/IDistractionRecorder.sol";

contract MockDistractionRecorder {
    mapping(address => uint256) public mockRecordCounts;
    mapping(address => IDistractionRecorder.DistractionRecord[]) private mockRecordsStorage;

    uint256 public getDriverRecordsCallCount;
    address public lastQueriedDriver;
    uint256 public lastOffset;
    uint256 public lastLimit;

    function setMockRecordCount(address driver, uint256 count) external {
        mockRecordCounts[driver] = count;
    }

    function setMockRecords(address driver, IDistractionRecorder.DistractionRecord[] memory records) external {
        delete mockRecordsStorage[driver];
        for (uint256 i = 0; i < records.length; i++) {
            mockRecordsStorage[driver].push(records[i]);
        }
    }

    function getDriverRecordCount(address driver) external view returns (uint256) {
        return mockRecordCounts[driver];
    }

    function getDriverRecords(address driver, uint256 offset, uint256 limit)
        external
        returns (IDistractionRecorder.DistractionRecord[] memory)
    {
        getDriverRecordsCallCount++;
        lastQueriedDriver = driver;
        lastOffset = offset;
        lastLimit = limit;

        IDistractionRecorder.DistractionRecord[] storage allRecords = mockRecordsStorage[driver];
        uint256 totalRecords = allRecords.length;

        if (offset >= totalRecords || limit == 0) {
            return new IDistractionRecorder.DistractionRecord[](0);
        }

        uint256 end = offset + limit;
        if (end > totalRecords) {
            end = totalRecords;
        }

        uint256 resultLength = end - offset;
        IDistractionRecorder.DistractionRecord[] memory result =
            new IDistractionRecorder.DistractionRecord[](resultLength);

        for (uint256 i = 0; i < resultLength; i++) {
            result[i] = allRecords[offset + i];
        }

        return result;
    }

    function resetCallTracking() external {
        getDriverRecordsCallCount = 0;
        lastQueriedDriver = address(0);
        lastOffset = 0;
        lastLimit = 0;
    }
}
