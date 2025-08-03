# Smart Contract Public Records Management and Open Government System

## Overview

This system provides a comprehensive blockchain-based solution for managing government records, ensuring transparency, privacy protection, and compliance with legal requirements. The system consists of five interconnected smart contracts that work together to create a robust public records management platform.

## System Architecture

### Core Contracts

1. **Document Authentication Contract** (`document-auth.clar`)
    - Ensures government documents are tamper-proof and verifiable
    - Creates cryptographic hashes for document integrity
    - Manages document versioning and audit trails

2. **Public Access Request Management Contract** (`access-request.clar`)
    - Streamlines citizen access to government records
    - Handles FOIA (Freedom of Information Act) requests
    - Manages request status and response timelines

3. **Data Privacy Protection Contract** (`privacy-protection.clar`)
    - Redacts sensitive information from public records
    - Manages privacy classifications and access levels
    - Ensures compliance with privacy regulations

4. **Records Retention Scheduling Contract** (`retention-schedule.clar`)
    - Automates document archiving and disposal
    - Implements legal retention requirements
    - Manages lifecycle of government records

5. **Government Transparency Reporting Contract** (`transparency-report.clar`)
    - Provides citizens with clear information about government operations
    - Generates transparency metrics and reports
    - Tracks government accountability measures

## Key Features

### Document Authentication
- Cryptographic document verification
- Immutable audit trails
- Version control and change tracking
- Digital signatures for authorized personnel

### Access Management
- Citizen request processing
- Automated response workflows
- Status tracking and notifications
- Appeal process management

### Privacy Protection
- Automated sensitive data detection
- Configurable redaction rules
- Access level management
- Compliance reporting

### Retention Management
- Legal compliance automation
- Scheduled archiving and disposal
- Retention policy enforcement
- Audit trail preservation

### Transparency Reporting
- Real-time government metrics
- Public dashboard data
- Accountability tracking
- Citizen engagement statistics

## Data Structures

### Document Record
- Document ID (unique identifier)
- Content hash (SHA-256)
- Classification level
- Creation timestamp
- Last modified timestamp
- Author/department
- Retention schedule

### Access Request
- Request ID
- Citizen identifier
- Document references
- Request type (FOIA, general access)
- Status (pending, approved, denied, fulfilled)
- Response deadline
- Processing notes

### Privacy Classification
- Classification level (public, restricted, confidential)
- Redaction rules
- Access permissions
- Review requirements

## Security Features

- Multi-signature requirements for sensitive operations
- Role-based access control
- Audit logging for all operations
- Cryptographic integrity verification
- Time-locked operations for compliance

## Compliance Standards

- Freedom of Information Act (FOIA)
- Government Records Act
- Privacy Act requirements
- Data retention regulations
- Open government initiatives

## Installation and Setup

1. Install Clarinet CLI
2. Clone this repository
3. Run `clarinet check` to validate contracts
4. Run `npm test` to execute test suite
5. Deploy contracts using `clarinet deploy`

## Usage Examples

### Authenticating a Document
\`\`\`clarity
(contract-call? .document-auth authenticate-document
"doc-123"
0x1234567890abcdef
"Department of Health"
u365)
\`\`\`

### Submitting an Access Request
\`\`\`clarity
(contract-call? .access-request submit-request
'SP1234567890ABCDEF
"doc-123"
"FOIA request for health records")
\`\`\`

### Setting Privacy Classification
\`\`\`clarity
(contract-call? .privacy-protection classify-document
"doc-123"
u2
"Contains personal health information")
\`\`\`

## Testing

The system includes comprehensive tests using Vitest:
- Unit tests for each contract function
- Integration tests for cross-contract workflows
- Edge case and error condition testing
- Performance and gas optimization tests

Run tests with:
\`\`\`bash
npm test
\`\`\`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For questions or support, please open an issue in the GitHub repository or contact the development team.
