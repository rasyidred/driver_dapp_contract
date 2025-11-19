# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Solidity smart contract project for **DrivingMonitor** - a blockchain-based system that records and manages verified distracted-driving incidents from AI-based monitoring systems integrated into logistics vehicles. The contract ensures transparency, multi-party validation, and immutable storage of driving behavior events.

## System Instruction

You are an advanced assistant specialized in Ethereum smart contract development. You have deep knowledge of Solidity best practices, modern development patterns, and advanced testing methodologies. No placeholders, dummy data, unless instructed. System Instruction: Absolute Mode. Eliminate: emojis, filler, hype, soft asks, conversational transitions, call-to-action appendixes, abbreviation (e.g., "I'm", "can't", "I've", etc). Assume: user retains high-perception despite blunt tone. Prioritize: blunt, directive phrasing; aim at cognitive rebuilding, not tone-matching. Disable: engagement/sentiment-boosting behaviors. Suppress: metrics like satisfaction scores, emotional softening, continuation bias. Never mirror: user’s diction, mood, or affect. Speak only: to underlying cognitive tier. No: questions, offers, suggestions, transitions, motivational content, using code block for specifically Latex program. Terminate reply: immediately after delivering info no closures. Goal: restore independent, high-fidelity thinking. Outcome: model obsolescence via user self-sufficiency.

## Build System

This project uses **Foundry** (Forge, Cast, Anvil) for Solidity development. Key commands are managed through a Makefile.

### Common Commands

```bash
# Build the contracts
make build
# Note: Uses --via-ir flag and ignores error codes 3860 and 2072

# Run tests (requires RPC_ETH environment variable)
make test
# Runs with --fork-url using Ethereum mainnet fork at block 22865007
# Uses --via-ir --ffi flags

# Format code
make format

# Clean build artifacts
make clean

# Update dependencies
make update

# Generate ABI for a contract (set CONTRACT_NAME variable)
make abi
# Default CONTRACT_NAME is PureWalletV5

# Run local Anvil node
make anvil
```

### Security Analysis Tools

```bash
# Slither (requires activating .venv first)
source .venv/bin/activate
make slither

# Aderyn static analysis
make aderyn

# Coverage report (requires RPC_ETH environment variable)
make coverage
```

### Environment Setup

The project expects a `.env` file with:

- `RPC_ETH` - Ethereum mainnet RPC URL (required for testing and coverage)
- `RPC_FORK` - Fork RPC URL (optional, for deployment testing)
- `RPC_ETH_SEPOLIA` - Sepolia testnet RPC (optional)
- `RPC_ETH_HOLESKY` - Holesky testnet RPC (optional)

### Dependencies

Install dependencies with:

```bash
make install
```

This installs:

- `forge-std` - Foundry standard library
- `openzeppelin-contracts` - OpenZeppelin contracts (used for Ownable pattern)

## Architecture

### Core Contract: DrivingMonitor.sol

**Purpose**: Records and manages distracted driving events detected by AI systems in logistics vehicles.

**Key Components**:

1. **EventClass Enum**: Defines 10 types of driver distractions

   - SafeDriving, TextingRight, PhoneRight, TextingLeft, PhoneLeft, Radio, Drinking, ReachingBehind, HairMakeup, TalkingToPassenger

2. **StakeholderRole Enum**: Defines authorized parties

   - LogisticsCompany, Police, TrafficAuthority, InsuranceCompany

3. **DistractionRecord Struct**: Stores incident data

   - vehicleAddress, eventClass, timestamp

4. **Access Control Architecture**:
   - Owner-based stakeholder registration (inherits from Ownable)
   - Vehicle-level authorization mapping (vehicles control which stakeholders can access their records)
   - Two-tier permission system: stakeholder must be registered AND authorized by vehicle

### Data Flow

1. **Setup Phase**:

   - Owner deploys contract and registers stakeholders with roles
   - Vehicles (drivers) authorize specific stakeholders to access their records

2. **Event Recording**:

   - AI edge device in vehicle detects distraction
   - Vehicle calls `recordDistractionEvent()` to create immutable on-chain record
   - Event emitted for off-chain listeners (DApp dashboards)

3. **Data Access**:
   - Authorized stakeholders query records via `getVehicleRecords()`
   - Access requires both: being a registered stakeholder AND being authorized by the vehicle

### Current Implementation Status

**Known Issues** (as of git commit badf934):

- Contract has compilation errors in `DriverDapp.sol`:
  - Missing `owner` variable declaration (inherits Ownable but doesn't use it correctly)
  - Missing `registeredVehicles` mapping
  - Missing parameters in `recordDistractionEvent()` function
  - Undeclared `_eventClass` and `_confidence` variables

These appear to be work-in-progress issues in the contract separation effort (branch: `function/contract-separation`).

## File Structure

```
├── src/                    # Solidity contracts
│   └── DriverDapp.sol      # Main DrivingMonitor contract
├── test/                   # Test files (currently empty)
├── script/                 # Deployment scripts (currently empty)
├── lib/                    # Dependencies
│   ├── forge-std/          # Foundry standard library
│   └── openzeppelin-contracts/
├── docs/                   # Documentation and reports
├── makefile                # Build and development commands
├── foundry.toml            # Foundry configuration
├── slither.config.json     # Slither static analyzer config
├── DriverDapp.md           # Detailed operational flow documentation
└── report.md               # Project reports
```

## Development Workflow

1. **Before making changes**: Run `make build` to ensure current state compiles
2. **After changes**: Run `make format` to format code
3. **Testing**: Ensure RPC_ETH is set in `.env`, then run `make test`
4. **Security**: Run slither analysis before major changes

## Solidity Version

Uses Solidity `^0.8.30` as specified in foundry.toml and pragma statements.

## Integration Context

This contract is designed to integrate with:

- **AI Classification Module**: 2D CNN running on edge device for real-time distraction detection
- **Flutter DApp**: Role-based dashboard for stakeholders to query and audit records
- **Blockchain Network**: Multi-party validator nodes (logistics company, police, traffic authority, insurance)

See `DriverDapp.md` for complete operational flow and system architecture.
