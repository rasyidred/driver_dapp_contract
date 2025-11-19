# DrivingMonitor Smart Contract — Operational Flow

## Overview

The **DrivingMonitor** contract provides a blockchain-based mechanism to store and manage verified distracted-driving incidents from AI-based monitoring systems integrated into logistics vehicles. It ensures transparency, multi-party validation, and immutable storage.

---

## System Components

1. **Logistic Vehicle**

   - Equipped with dashboard camera and edge-processing unit.
   - Runs real-time AI classifier (2D CNN) detecting distraction.
   - Triggers alerts and sends confirmed cases for blockchain recording.

2. **AI Classification Module**

   - Preprocesses video frames.
   - Classifies driver actions into predefined distraction classes.
   - Outputs `(eventClass, confidence)`.

3. **Blockchain Network**

   - Hosts `DrivingMonitor.sol`.
   - Validator nodes: Logistics Company, Police, Traffic Authority, Insurance Firm.
   - Immutable distributed ledger stores distracted-driving records.

4. **Stakeholder Access Layer**
   - Flutter-based DApp providing role-based data access.
   - Stakeholders view, query, and audit on-chain events.

---

## Step-by-Step Flow

### 1. Deployment & Setup

- The contract is deployed by an **administrator (owner)**.
- The owner registers participants using:
  ```solidity
  registerStakeholder(address stakeholder, StakeholderRole role)
  ```
- Roles include: LogisticsCompany, Police, TrafficAuthority, InsuranceCompany.

### 2. Driver Authorization

- Driver authorizes which stakeholders can access their records:
  ```solidity
  addAuthorizedStakeholder(address stakeholder)
  ```
- Driver can revoke access:
  ```solidity
  removeAuthorizedStakeholder(address stakeholder)
  ```

### 3. AI Event Detection

- The dashboard camera streams frames to the AI classification module.
- The CNN classifier labels the action (e.g., “TextingRight”).
- If distraction is detected, the system triggers:
  - Alarm system (driver alert).
  - Re-check module for confirmation.

### 4. On-Chain Record Creation

- After confirmation, edge device (or authorized stakeholder node) sends the record:
  ```solidity
  recordDistractedDriving(driverAddress, timestamp, eventClass)
  ```
- Parameters:

  - `driverAddress`: wallet of driver.
  - `timestamp`: event detection time (Unix format).
  - `eventClass`: enum type (e.g., Drinking, Radio, PhoneLeft).

- The transaction emits:
  ```solidity
  event DistractedDrivingRecorded(driver, recordId, timestamp, eventClass, reporter)
  ```

### 5. Blockchain Propagation

- The transaction is broadcast to validator nodes.
- Each validator verifies and stores it in the distributed ledger.
- Event data (`timestamp, eventClass, blockNumber`) becomes immutable.

### 6. Record Query

- Authorized stakeholders or the driver call:
  ```solidity
  getDistractedDrivingEvents(driverAddress)
  ```
- Returns a list of `DistractionRecord` structs:
  - `timestamp`
  - `eventClass`
  - `blockNumber`

### 7. Stakeholder Dashboard Access

- The Flutter DApp connects to blockchain through Web3.py interface.
- Role-based authentication determines accessible data:
  - Logistics companies review fleet driver incidents.
  - Police and Traffic Authorities audit verified violations.
  - Insurance companies assess claims linked to driving behavior.

### 8. Continuous Governance

- Owner can revoke stakeholders:
  ```solidity
  revokeStakeholder(address stakeholder)
  ```
- Drivers maintain full control of data visibility.
- Stakeholders rely on immutable logs for validation, reporting, or analytics.

---

## Data Flow Summary

| Source         | Destination | Method                         | Description                    |
| -------------- | ----------- | ------------------------------ | ------------------------------ |
| AI Edge Device | Blockchain  | `recordDistractedDriving()`    | Submits distraction event      |
| Blockchain     | DApp        | Event Logs                     | Updates stakeholder dashboards |
| Driver         | Blockchain  | `addAuthorizedStakeholder()`   | Grants access                  |
| Stakeholder    | Blockchain  | `getDistractedDrivingEvents()` | Retrieves driver data          |
| Owner          | Blockchain  | `registerStakeholder()`        | Adds node participants         |

---

## Security Considerations

- **Access Control**: Only authorized stakeholders can query driver data.
- **Integrity**: All records timestamped and block-linked.
- **Privacy**: Raw video data never stored on-chain.
- **Auditability**: Each transaction emits verifiable on-chain events.

---

## Typical Interaction Flow

1. AI detects distraction.
2. Edge system confirms and triggers blockchain transaction.
3. `DrivingMonitor.recordDistractedDriving()` logs event.
4. Validators verify and commit to immutable ledger.
5. Stakeholders query and review events via DApp.
6. Owner or driver manages access and permissions.

---

**End of Document**
