# Project Issues Report

This document lists all identified issues and broken features in the DBMS project.

---

## 1. Reports Feature Issues

### Problem: Hash Fields Missing from Generated Prisma Client
- **Location**: `backend/generated/prisma/schema.prisma`
- **Issue**: The generated Prisma client is missing `previous_hash` and `current_hash` fields that are defined in the main schema and documented in `docs/reports-table.md`
- **Expected fields**:
  - `previous_hash String? @db.Text`
  - `current_hash String? @db.Text`
- **Impact**: Reports cannot be hash-chained for integrity verification

### Problem: No POST Endpoint for Reports
- **Location**: `backend/main.ts`
- **Issue**: No API route exists to create/upload medical reports
- **Impact**: Doctors cannot upload reports to patients

### Problem: Hardcoded Report Count in Frontend
- **Location**: `pgi_app/lib/home_page.dart:35`
- **Issue**: Shows static value `'13'` instead of fetching from API
- **Current Code**:
  ```dart
  _statBox('Pending Reports', '13', isWideScreen)
  ```

### Problem: Upload Page Has No Logic
- **Location**: `pgi_app/lib/upload_page.dart:37-39`
- **Issue**: Upload button has empty onPressed handler
- **Current Code**:
  ```dart
  ElevatedButton.icon(
    onPressed: () {
      // Upload logic placeholder
    },
  ```

---

## 2. Frontend Using Hardcoded Data (Not Connected to Backend)

### Home Page Hardcoded Values
- **Location**: `pgi_app/lib/home_page.dart`
- **Line 20**: Hardcoded greeting `Hello, Yuvraj!` (should use account API)
- **Line 34**: `Total Patients` → `'52'` (should fetch from API)
- **Line 77-78**: Hardcoded patient cards `'Aditi Sharma'`, `'Rahul Verma'`

### Today's Appointments Hardcoded
- **Location**: `pgi_app/lib/home_page.dart:50-51`
  ```dart
  _appointmentCard('Rakesh Gupta', '10:30 AM'),
  _appointmentCard('Meena Joshi', '11:00 AM'),
  ```

### Patient Records Hardcoded List
- **Location**: `pgi_app/lib/records_page.dart:15-40`
- **Issue**: Static list in memory, no API calls
- **Example**:
  ```dart
  final List<Map<String, String>> _patients = [
    {'name': 'Aditi Sharma', 'id': 'P1001', ...},
    {'name': 'Rahul Verma', 'id': 'P1002', ...},
  ];
  ```

---

## 3. Backend API Gaps

### Missing Endpoints in `backend/main.ts`

| Endpoint | Method | Status |
|----------|--------|--------|
| `/patients` | POST | Missing |
| `/patients/:id` | PUT/PATCH | Missing |
| `/patients/:id` | DELETE | Missing |
| `/reports` | POST | Missing |
| `/reports` | GET | Missing |
| `/prescribe` | POST | Missing |
| `/analytics/integrity` | GET | Exists but may fail |

---

## 4. Schema Synchronization Issue

### Problem: Prisma Generate Not Run
- **File**: `backend/generated/prisma/schema.prisma`
- **Issue**: Schema was updated in `backend/prisma/schema.prisma` but `npx prisma generate` was not run to regenerate the client
- **Solution**: Run `npx prisma generate` in the backend directory

---

## 5. Security Issues

### Problem: Plain Text Password Comparison
- **Location**: `auth/main.js:55`
- **Issue**: Uses plain text comparison instead of bcrypt
- **Current Code**:
  ```javascript
  const isMatch = password === user.pwd ? true : false;
  ```
- **Risk**: Passwords stored in plain text in database

### Problem: Missing Environment Validation
- **Issue**: No validation on startup for required `.env` variables
- **Impact**: Application may fail silently with unclear errors

---

## 6. Documentation Issues

### `TODO.md` Incomplete
- **Location**: `TODO.md`
- **Current Content**: Only 2 items listed
- **Issue**: Does not reflect actual project state

---

## Summary Table

| Issue | Severity | Location |
|-------|----------|----------|
| Missing hash fields in generated client | High | `backend/generated/prisma/schema.prisma` |
| No POST /reports endpoint | High | `backend/main.ts` |
| Frontend uses hardcoded data | Medium | `pgi_app/lib/*.dart` |
| Upload page not implemented | Medium | `pgi_app/lib/upload_page.dart` |
| Missing API endpoints | Medium | `backend/main.ts` |
| Plain text passwords | High | `auth/main.js` |
| Schema sync issue | Medium | Prisma configuration |

---

## Recommended Actions

1. Run `npx prisma generate` in backend directory
2. Implement API endpoints for POST/PUT/DELETE operations
3. Connect Flutter frontend to backend API
4. Implement upload page with actual file handling
5. Switch to hashed passwords with bcrypt
6. Update TODO.md with actual tracking items