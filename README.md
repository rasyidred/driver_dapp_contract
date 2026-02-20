# DRIVERDAPP — Smart Contract Layer

Solidity smart contracts for immutable, auditable recording and access-controlled retrieval of AI-detected driver distraction events in intelligent transportation systems.

---

## Abstract

> Existing driver distraction detection systems face critical barriers to real-world deployment in safety-critical transportation environments, including the lack of real-time edge inference, explainable artificial intelligence (AI), trustworthy event logging, and privacy-preserving evidence management. To overcome these challenges, this paper presents an integrated framework, termed *DRIVERDAPP*, that unifies real-time edge-based detection, AI explainability, and secure, auditable event management. Red–green–blue (RGB) in-cabin image frames captured by a dashboard camera are processed locally on an NVIDIA Jetson Nano edge device, where a fine-tuned You Only Look Once version 11 small (YOLOv11s) model classifies ten driver behavior states and triggers in-vehicle audio alerts for unsafe activities. To suppress transient misclassifications under edge constraints, distraction persistence is verified using a lightweight temporal confirmation strategy. Confirmed distraction events are immutably recorded via Solidity-based smart contracts and submitted through the Web3.py interface to a permissioned Hyperledger Besu consortium blockchain operating under Quorum Byzantine Fault Tolerance (QBFT) consensus. Privacy is preserved by retaining raw visual data off-chain, while only pseudo-anonymous identifiers and event metadata are stored on-chain under controlled access policies. Model interpretability is enabled using Gradient-weighted Class Activation Mapping (Grad-CAM), providing transparent visual explanations of distraction-related predictions. The framework is evaluated using the State Farm Distracted Driver and American University in Cairo datasets, demonstrating stable real-time edge operation, negligible blockchain query latency, and secure smart contract execution. These results confirm the suitability of *DRIVERDAPP* for secure, explainable, and deployable driver monitoring in intelligent transportation systems.

---

## System Overview

DRIVERDAPP is a multi-component framework. This repository contains only the **smart contract layer**. The full pipeline is:

1. **Edge Device** — NVIDIA Jetson Nano with dashboard camera captures RGB in-cabin frames in real time.
2. **AI Classification** — A fine-tuned YOLOv11s model classifies frames into 10 driver behavior states and triggers in-vehicle audio alerts.
3. **Temporal Confirmation** — A lightweight re-check module suppresses transient misclassifications before events are submitted on-chain.
4. **Blockchain Recording** — Confirmed events are submitted via Web3.py to a permissioned Hyperledger Besu network (QBFT consensus). Event metadata is stored immutably on-chain; raw video data is retained off-chain.
5. **Stakeholder Access** — A Flutter DApp connects to the blockchain and provides role-based dashboards for authorized parties (insurance companies, law enforcement, fleet managers, regulatory bodies).
6. **Explainability** — Grad-CAM generates visual explanations of model predictions for transparency.

---

## Architecture

The contract layer consists of two contracts and two interfaces:

### AccessRegistry.sol

Central registry and data gateway.

- Owner-controlled stakeholder registration with role assignments (RBAC).
- Driver-controlled authorization: stakeholders are denied access by default and must be explicitly approved by the driver.
- Acts as an API gateway: proxies paginated record queries to `DistractionRecorder` and aggregates record count metadata for frontend pagination.
- Manages driver-to-vehicle-number associations used at recording time.

### DistractionRecorder.sol

Immutable distraction event storage.

- Stores `DistractionRecord` structs in per-driver mappings indexed by sequential record ID.
- Exposes one dedicated recording function per distraction class (called by the edge device).
- Resolves vehicle number from `AccessRegistry` at recording time; falls back to `"XXX-0000"` if the driver has no registered vehicle.
- Record retrieval is paginated and restricted to the `AccessRegistry` caller only — all authorization checks happen in `AccessRegistry` before the proxy call.

### Access Control Model

Two-tier authorization is enforced on every query:

1. The caller must be a registered stakeholder (or the driver themselves).
2. The driver must have explicitly authorized that stakeholder.

| Actor | Responsibilities |
|---|---|
| Owner (IT Department) | Deploy contracts, register stakeholders, assign vehicle numbers |
| Driver | Authorize and revoke stakeholder access; record own distraction events |
| Edge Device | Call event recording functions on behalf of the driver's address |
| Stakeholder | Query distraction records through the AccessRegistry gateway |

---

## Distraction Event Classes

Defined in `IDistractionRecorder.EventClass`:

| Index | Class |
|---|---|
| 0 | SafeDriving |
| 1 | TextingRight |
| 2 | PhoneRight |
| 3 | TextingLeft |
| 4 | PhoneLeft |
| 5 | Radio |
| 6 | Drinking |
| 7 | ReachingBehind |
| 8 | HairMakeup |
| 9 | TalkingToPassenger |

---

## Stakeholder Roles

Defined in `IAccessRegistry.StakeholderRole`:

| Role | Description |
|---|---|
| `InsuranceCompany` | Assesses claims linked to driving behavior |
| `LawEnforcement` | Audits verified violations |
| `FleetManager` | Reviews fleet driver incidents |
| `RegulatoryBody` | Monitors compliance and analytics |

---

## Quickstart

### Prerequisites

- [Foundry](https://getfoundry.sh) installed:
  ```bash
  curl -L https://foundry.paradigm.xyz | bash && foundryup
  ```
- A `.env` file in the project root with:
  ```
  RPC_ETH=<ethereum_mainnet_rpc_url>
  ```

### Install Dependencies

```bash
make install
```

Installs `forge-std` and OpenZeppelin contracts.

### Build

```bash
make build
```

### Run Tests

```bash
make test
```

Tests run against an Ethereum mainnet fork (block 22865007). `RPC_ETH` must be set.

### Format Code

```bash
make format
```

### Local Development Node

```bash
make anvil
```

### Deploy

```bash
# Local Anvil
make deploy-local

# Sepolia testnet
make deploy-sepolia

# Mainnet
make deploy-mainnet
```

Deployment is automated via `script/DeploymentScript.s.sol`: `AccessRegistry` is deployed first, then `DistractionRecorder` is deployed with the registry address. Both contracts set the deployer as owner.

Dry-run variants (`deploy-local-dry`, `deploy-sepolia-dry`, `deploy-mainnet-dry`) are also available.

### Security Analysis

```bash
# Slither (activate .venv first)
source .venv/bin/activate
make slither

# Aderyn
make aderyn

# Coverage report
make coverage
```

---

## Main Functions

### AccessRegistry — Admin Functions (owner only)

| Function | Parameters | Description |
|---|---|---|
| `registerStakeholder` | `address _stakeholder, StakeholderRole _role` | Register an entity with a role; role must not be `None` |
| `revokeStakeholder` | `address _stakeholder` | Remove registration and set role to `None` |
| `updateVehicleForDriver` | `address _driver, string _plateNo` | Assign or update a vehicle plate number for a driver |
| `setDistractionRecorder` | `address _distractionRecorder` | Link the `DistractionRecorder` contract address |

### AccessRegistry — Driver Functions

| Function | Parameters | Description |
|---|---|---|
| `addAuthorizedStakeholder` | `address _stakeholder` | Grant a registered stakeholder access to the caller's records |
| `removeAuthorizedStakeholder` | `address _stakeholder` | Revoke a stakeholder's access to the caller's records |

### AccessRegistry — Data Gateway

| Function | Parameters | Returns | Description |
|---|---|---|---|
| `getDistractedDrivingEvents` | `address _driver, uint256 _offset, uint256 _limit` | `DistractionRecord[] records, uint256 totalCount` | Paginated record retrieval with full authorization checks. Callable by the driver or any stakeholder the driver has authorized. Returns both the record page and the total record count for pagination metadata. |

### AccessRegistry — View Functions

| Function | Returns | Description |
|---|---|---|
| `isAuthorized(address _driver, address _stakeholder)` | `bool` | Whether the driver has authorized the stakeholder |
| `isRegisteredStakeholder(address _stakeholder)` | `bool` | Whether the address has a non-None role |
| `getStakeholderRole(address _stakeholder)` | `StakeholderRole` | Role assigned to the stakeholder |
| `getDriverVehicleNumber(address _driver)` | `string` | Vehicle plate number registered for the driver |

---

### DistractionRecorder — Event Recording

Called by the edge device using the driver's address as `msg.sender`. Each function records one distraction class and returns the assigned record ID (0-based, sequential per driver).

| Function | Distraction Class | Returns |
|---|---|---|
| `recordDistractionEventTextingRight()` | TextingRight | `uint256 recordId` |
| `recordDistractionEventPhoneRight()` | PhoneRight | `uint256 recordId` |
| `recordDistractionEventTextingLeft()` | TextingLeft | `uint256 recordId` |
| `recordDistractionEventPhoneLeft()` | PhoneLeft | `uint256 recordId` |
| `recordDistractionEventRadio()` | Radio | `uint256 recordId` |
| `recordDistractionEventDrinking()` | Drinking | `uint256 recordId` |
| `recordDistractionEventReachingBehind()` | ReachingBehind | `uint256 recordId` |
| `recordDistractionEventHairMakeup()` | HairMakeup | `uint256 recordId` |
| `recordDistractionEventTalkingToPassenger()` | TalkingToPassenger | `uint256 recordId` |

### DistractionRecorder — View Functions

| Function | Returns | Description |
|---|---|---|
| `getDriverRecordCount(address _driver)` | `uint256` | Total number of records stored for the driver |
| `getDriverVehicleNumber(address _driver)` | `string` | Vehicle plate resolved from `AccessRegistry` |
| `getDriverRecords(address _driver, uint256 _offset, uint256 _limit)` | `DistractionRecord[]` | Paginated records; restricted to `AccessRegistry` caller only |

### DistractionRecorder — Admin Functions (owner only)

| Function | Parameters | Description |
|---|---|---|
| `setAccessRegistry` | `address _newRegistry` | Update the linked `AccessRegistry` address |

---

## Events

### AccessRegistry

| Event | Parameters | Emitted When |
|---|---|---|
| `StakeholderRegistered` | `address indexed stakeholder, StakeholderRole indexed role` | Stakeholder is registered |
| `StakeholderRevoked` | `address indexed stakeholder` | Stakeholder registration is removed |
| `StakeholderAuthorized` | `address indexed driver, address indexed stakeholder` | Driver grants access |
| `StakeholderDeauthorized` | `address indexed driver, address indexed stakeholder` | Driver revokes access |
| `VehicleNumberUpdated` | `address indexed driver, string indexed vehicleNumber, uint256 indexed timestamp` | Vehicle plate assigned or updated |
| `DistractionRecorderUpdated` | `address indexed newRecorder` | Recorder contract address updated |

### DistractionRecorder

| Event | Parameters | Emitted When |
|---|---|---|
| `DistractedDrivingRecorded` | `address indexed driver, string indexed vehicleNumber, EventClass indexed eventClass, uint256 timestamp, uint256 recordId` | A distraction event is recorded |
| `AccessRegistryUpdated` | `address indexed newRegistry` | Registry address updated |

---

## Data Structures

```solidity
struct DistractionRecord {
    string vehicleNumber;   // plate number at time of event
    EventClass eventClass;  // distraction class
    uint256 timestamp;      // block.timestamp at time of recording
}
```

---

## Error Reference

| Error Code | Contract | Condition |
|---|---|---|
| `AR_ZeroAddress` | AccessRegistry | Provided address is `address(0)` |
| `AR_InvalidRole` | AccessRegistry | Role argument is `None` |
| `AR_NotRegistered` | AccessRegistry | Target stakeholder is not registered |
| `AR_UnknownEntity` | AccessRegistry | Driver tried to authorize an unregistered address |
| `AR_RecorderNotSet` | AccessRegistry | `DistractionRecorder` address not configured |
| `AR_UnauthorizedStakeholder` | AccessRegistry | Caller is not a registered stakeholder |
| `AR_AccessDenied` | AccessRegistry | Driver has not authorized the caller |
| `DR_ZeroAddress` | DistractionRecorder | Provided address is `address(0)` |
| `DR_RegistryNotSet` | DistractionRecorder | `AccessRegistry` address not configured |
| `DR_UnauthorizedAccessRegistry` | DistractionRecorder | Caller is not the configured `AccessRegistry` |

---

## Repository Structure

```
src/
  AccessRegistry.sol          # RBAC registry and data gateway
  DistractionRecorder.sol     # Immutable distraction event storage
  interfaces/
    IAccessRegistry.sol       # AccessRegistry interface
    IDistractionRecorder.sol  # DistractionRecorder interface, EventClass enum, DistractionRecord struct
test/
  AccessRegistry.t.sol        # 69 tests across 11 categories
  DistractionRecorder.t.sol   # 57 tests across 11 categories
  mocks/
    MockDistractionRecorder.sol
script/
  DeploymentScript.s.sol      # Automated deployment (AccessRegistry → DistractionRecorder)
```

---

## Technical Specifications

| Property | Value |
|---|---|
| Solidity version | 0.8.30 |
| Build toolchain | Foundry (Forge, Cast, Anvil) |
| Dependencies | OpenZeppelin Contracts (Ownable), forge-std |
| Blockchain target | Hyperledger Besu (QBFT consensus) |
| Test framework | Forge Test (126 tests total) |

---

## License

MIT
