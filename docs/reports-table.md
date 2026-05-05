# Reports Table Documentation

## Overview

The `Report` table is a core component of the DBMS project, designed to store and manage medical reports associated with patients. It integrates with the system's blockchain-based integrity verification to ensure report authenticity and prevent tampering.

## Database Schema

```prisma
model Report {
  reportid      Int       @id @default(autoincrement())
  patientid     Int? 
  type_         String    @db.VarChar(100) @map("type")
  date_uploaded DateTime? 
  previous_hash String?   @db.Text
  current_hash  String?   @db.Text

  patient       Patient?  @relation(fields: [patientid], references: [patientid])

  @@map("reports")
}
```

## Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `reportid` | Int | Primary key, auto-incremented unique identifier for each report |
| `patientid` | Int? | Foreign key referencing the Patient table. Nullable to allow standalone reports |
| `type_` | String (VarChar 100) | The type of medical report (e.g., "Lab Results", "X-Ray", "Prescription") |
| `date_uploaded` | DateTime | Timestamp when the report was uploaded to the system |
| `previous_hash` | Text | Blockchain hash of the previous report in the chain (for integrity tracking) |
| `current_hash` | Text | Current blockchain hash of this report (for tamper detection) |

## Relationships

- **Patient (One-to-Many)**: Each patient can have multiple reports. The relationship is defined via `@relation` on the `patientid` field.
- The relation is optional (`Patient?`) allowing reports to exist without being immediately linked to a patient.

## Key Features

### Blockchain Integration
The `previous_hash` and `current_hash` fields implement a blockchain-based integrity system:
- Every report stores a cryptographic hash
- Each new report references the previous report's hash
- This creates an immutable chain - any modification to a report would break the hash chain

### Data Integrity
The system ensures:
- Tamper-evident storage of medical records
- Traceability of report history
- Verification that reports have not been altered after creation

## API Endpoints

Reports are accessible through the following backend endpoints:

### GET /patients
Returns all patients with their associated reports:
```typescript
const patients = await securePrisma.patient.findMany({
  include: {
    reports: true
  }
});
```

### GET /patient/:id
Returns a specific patient with their reports and prescriptions:
```typescript
const patient = await securePrisma.patient.findUnique({
  where: { patientid: patientId },
  include: {
    reports: true,
    prescriptions: {
      include: {
        employee: true
      }
    }
  }
});
```

## Frontend Usage

In the Flutter application (`pgi_app/lib/home_page.dart`), the Reports table is referenced in the dashboard statistics:

```dart
_statBox('Pending Reports', '13', isWideScreen)
```

Note: The current implementation shows a static value (13) rather than dynamically fetching from the API.

## Security Considerations

- Row-Level Security (RLS) policies apply to the Reports table
- Access is controlled through the `prisma.$withUser(employeeId)` extension
- Only authorized employees can view reports for their assigned patients

## Related Components

- **PatientHistory Table**: Tracks changes to patient records over time
- **SystemAuditLog Table**: Records system events and doctor activities
- **Prescribe Table**: Links doctors to patients for prescription management

## Implementation Location

- **Prisma Schema**: `backend/prisma/schema.prisma` (lines 49-60)
- **API Handlers**: `backend/main.ts`
- **Flutter Frontend**: `pgi_app/lib/home_page.dart`