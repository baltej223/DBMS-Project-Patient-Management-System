-- Row-Level Security (RLS) & Temporal System-Versioning Setup for HMS
-- Final corrected version for your Prisma schema

-----------------------------------------------------------
-- PART 0: REQUIRED EXTENSIONS
-----------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-----------------------------------------------------------
-- PART 1: HELPER FUNCTION
-----------------------------------------------------------

DROP FUNCTION IF EXISTS get_current_employee_id();

CREATE OR REPLACE FUNCTION get_current_employee_id()
RETURNS INTEGER AS $$
BEGIN
    RETURN NULLIF(current_setting('app.current_employee_id', TRUE), '')::INTEGER;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-----------------------------------------------------------
-- PART 2: ENABLE RLS
-----------------------------------------------------------

ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescribe ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_history ENABLE ROW LEVEL SECURITY;

ALTER TABLE patients FORCE ROW LEVEL SECURITY;
ALTER TABLE reports FORCE ROW LEVEL SECURITY;
ALTER TABLE prescribe FORCE ROW LEVEL SECURITY;
ALTER TABLE patient_history FORCE ROW LEVEL SECURITY;

-----------------------------------------------------------
-- PART 3: DROP OLD POLICIES
-----------------------------------------------------------

DROP POLICY IF EXISTS patient_access_policy ON patients;
DROP POLICY IF EXISTS report_access_policy ON reports;
DROP POLICY IF EXISTS prescribe_access_policy ON prescribe;
DROP POLICY IF EXISTS history_access_policy ON patient_history;

-----------------------------------------------------------
-- PART 4: CREATE RLS POLICIES
-----------------------------------------------------------

-- PATIENTS
CREATE POLICY patient_access_policy
ON patients
FOR ALL
USING (
    EXISTS (
        SELECT 1
        FROM employees e
        WHERE e.employeeid = get_current_employee_id()
        AND e.role = 'admin'
    )
    OR patientid IN (
        SELECT patientid
        FROM prescribe
        WHERE employeeid = get_current_employee_id()
    )
);

-- REPORTS
CREATE POLICY report_access_policy
ON reports
FOR ALL
USING (
    EXISTS (
        SELECT 1
        FROM employees e
        WHERE e.employeeid = get_current_employee_id()
        AND e.role = 'admin'
    )
    OR patientid IN (
        SELECT patientid
        FROM prescribe
        WHERE employeeid = get_current_employee_id()
    )
);

-- PRESCRIBE
CREATE POLICY prescribe_access_policy
ON prescribe
FOR ALL
USING (
    EXISTS (
        SELECT 1
        FROM employees e
        WHERE e.employeeid = get_current_employee_id()
        AND e.role = 'admin'
    )
    OR employeeid = get_current_employee_id()
);

-- HISTORY
CREATE POLICY history_access_policy
ON patient_history
FOR SELECT
USING (
    EXISTS (
        SELECT 1
        FROM employees e
        WHERE e.employeeid = get_current_employee_id()
        AND e.role = 'admin'
    )
    OR patientid IN (
        SELECT patientid
        FROM prescribe
        WHERE employeeid = get_current_employee_id()
    )
);

-----------------------------------------------------------
-- PART 5: PATIENT HISTORY TABLE
-----------------------------------------------------------

CREATE TABLE IF NOT EXISTS patient_history (
    id SERIAL PRIMARY KEY,
    patientid INTEGER NOT NULL,
    name VARCHAR(100),
    age INTEGER,
    gender VARCHAR(10),
    phone_number VARCHAR(20),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    changed_by INTEGER,
    operation VARCHAR(10)
);

-----------------------------------------------------------
-- PART 6: PATIENT HISTORY TRIGGER
-----------------------------------------------------------

DROP FUNCTION IF EXISTS archive_patient_history() CASCADE;

CREATE OR REPLACE FUNCTION archive_patient_history()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO patient_history (
            patientid,
            name,
            age,
            gender,
            phone_number,
            changed_by,
            operation
        )
        VALUES (
            OLD.patientid,
            OLD.name,
            OLD.age,
            OLD.gender,
            OLD.phone_number,
            get_current_employee_id(),
            'DELETE'
        );
        RETURN OLD;

    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO patient_history (
            patientid,
            name,
            age,
            gender,
            phone_number,
            changed_by,
            operation
        )
        VALUES (
            OLD.patientid,
            OLD.name,
            OLD.age,
            OLD.gender,
            OLD.phone_number,
            get_current_employee_id(),
            'UPDATE'
        );
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS patient_changes_trigger ON patients;

CREATE TRIGGER patient_changes_trigger
BEFORE UPDATE OR DELETE
ON patients
FOR EACH ROW
EXECUTE FUNCTION archive_patient_history();

-----------------------------------------------------------
-- PART 7: ENSURE HASH COLUMNS EXIST
-----------------------------------------------------------

ALTER TABLE reports
ADD COLUMN IF NOT EXISTS previous_hash TEXT;

ALTER TABLE reports
ADD COLUMN IF NOT EXISTS current_hash TEXT;

-----------------------------------------------------------
-- PART 8: REPORT HASH CHAIN TRIGGER
-----------------------------------------------------------

DROP FUNCTION IF EXISTS calculate_report_hash() CASCADE;

CREATE OR REPLACE FUNCTION calculate_report_hash()
RETURNS TRIGGER AS $$
DECLARE
    prev_hash TEXT;
BEGIN
    -- Get latest report hash for patient
    SELECT current_hash
    INTO prev_hash
    FROM reports
    WHERE patientid = NEW.patientid
    ORDER BY date_uploaded DESC, reportid DESC
    LIMIT 1;

    -- Genesis hash
    IF prev_hash IS NULL THEN
        prev_hash := '0xGENESIS_SEED_00000000000000000000000000000000000000000000000000000';
    END IF;

    NEW.previous_hash := prev_hash;

    -- Corrected column name: type
    NEW.current_hash := encode(
        digest(
            COALESCE(NEW.patientid::TEXT, '0') ||
            COALESCE(NEW.type::TEXT, 'unknown') ||
            COALESCE(NEW.date_uploaded::TEXT, 'now') ||
            prev_hash,
            'sha256'
        ),
        'hex'
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS report_hash_trigger ON reports;

CREATE TRIGGER report_hash_trigger
BEFORE INSERT
ON reports
FOR EACH ROW
EXECUTE FUNCTION calculate_report_hash();

-----------------------------------------------------------
-- PART 9: INTEGRITY AUDIT VIEW
-----------------------------------------------------------

DROP VIEW IF EXISTS health_integrity_audit;

CREATE OR REPLACE VIEW health_integrity_audit AS
SELECT
    reportid,
    patientid,
    type AS report_type,
    current_hash,
    previous_hash,
    CASE
        WHEN current_hash = encode(
            digest(
                COALESCE(patientid::TEXT, '0') ||
                COALESCE(type::TEXT, 'unknown') ||
                COALESCE(date_uploaded::TEXT, 'now') ||
                previous_hash,
                'sha256'
            ),
            'hex'
        )
        THEN 'VERIFIED'
        ELSE 'TAMPERED_OR_CORRUPT'
    END AS integrity_status
FROM reports;

-----------------------------------------------------------
-- PART 10: SYSTEM AUDIT LOG TABLE (Optional)
-----------------------------------------------------------

CREATE TABLE IF NOT EXISTS system_audit_logs (
    log_id SERIAL PRIMARY KEY,
    event_name VARCHAR(100),
    performed_by INTEGER,
    event_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT
);
