-- ===========================================================
-- DBMS Project: Advanced SQL & PL/SQL Implementation
-- Course: UCS310 Database Management Systems
-- ===========================================================

-----------------------------------------------------------
-- 1. DATA DEFINITION LANGUAGE (DDL)
-----------------------------------------------------------
-- (Note: Tables are managed by Prisma, but manual DDL is included for rubrics)

-- Creating a temporary audit log table for system events
CREATE TABLE IF NOT EXISTS system_audit_logs (
    log_id SERIAL PRIMARY KEY,
    event_name VARCHAR(100),
    performed_by INTEGER,
    event_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    details TEXT
);

-----------------------------------------------------------
-- 2. DATA MANIPULATION LANGUAGE (DML)
-----------------------------------------------------------
-- Example insertions for demonstration
/*
INSERT INTO employees (name, email, role, pwd) VALUES ('Dr. Smith', 'smith@hospital.com', 'doctor', 'hashed_pwd');
INSERT INTO patients (name, age, gender, phone_number) VALUES ('John Doe', 45, 'Male', '1234567890');
*/

-----------------------------------------------------------
-- 3. ADVANCED SELECT QUERIES (Joins, Aggregates, Subqueries)
-----------------------------------------------------------

-- 3.1 VIEW: Detailed Patient-Doctor Assignment
CREATE OR REPLACE VIEW doctor_patient_details AS
SELECT 
    e.name AS doctor_name,
    p.name AS patient_name,
    p.age,
    p.gender
FROM employees e
JOIN prescribe pr ON e.employeeid = pr.employeeid
JOIN patients p ON pr.patientid = p.patientid
WHERE e.role = 'doctor';

-- 3.2 Aggregation: Count of reports per patient with HAVING clause
-- "Find patients who have more than 3 medical reports"
SELECT 
    patientid, 
    COUNT(reportid) as report_count
FROM reports
GROUP BY patientid
HAVING COUNT(reportid) > 3;

-- 3.3 Subquery: Find patients who have never been prescribed to a doctor
SELECT name 
FROM patients 
WHERE patientid NOT IN (SELECT patientid FROM prescribe);

-----------------------------------------------------------
-- 4. PL/SQL COMPONENTS (Procedures, Functions, Cursors)
-----------------------------------------------------------

-- 4.1 STORED PROCEDURE: Secure Patient Registration
-- This procedure handles atomic insertion into 'patients' and 'prescribe' tables
CREATE OR REPLACE PROCEDURE sp_register_patient_secure(
    p_name VARCHAR,
    p_age INTEGER,
    p_gender VARCHAR,
    p_phone VARCHAR,
    p_doctor_id INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_patient_id INTEGER;
BEGIN
    -- Start Transaction Logic is handled by the calling block or autocommit
    -- Insert into Patients
    INSERT INTO patients (name, age, gender, phone_number)
    VALUES (p_name, p_age, p_gender, p_phone)
    RETURNING patientid INTO new_patient_id;

    -- Link to Doctor in Prescribe table
    INSERT INTO prescribe (employeeid, patientid)
    VALUES (p_doctor_id, new_patient_id);

    -- Log the event
    INSERT INTO system_audit_logs (event_name, performed_by, details)
    VALUES ('PATIENT_REGISTRATION', p_doctor_id, 'Registered patient: ' || p_name);

    COMMIT;
    
EXCEPTION WHEN OTHERS THEN
    -- Robust Exception Handling
    ROLLBACK;
    RAISE NOTICE 'Error occurred during patient registration: %', SQLERRM;
END;
$$;

-- 4.2 CURSOR: Generate Medical Summary for all Doctors
-- This uses a cursor to iterate through doctors and log their total activity
CREATE OR REPLACE PROCEDURE sp_generate_doctor_activity_report()
LANGUAGE plpgsql
AS $$
DECLARE
    -- Declare Cursor
    doc_cursor CURSOR FOR SELECT employeeid, name FROM employees WHERE role = 'doctor';
    doc_record RECORD;
    patient_count INTEGER;
BEGIN
    OPEN doc_cursor;
    
    LOOP
        FETCH doc_cursor INTO doc_record;
        EXIT WHEN NOT FOUND;
        
        -- Calculate stats for this doctor
        SELECT COUNT(*) INTO patient_count 
        FROM prescribe 
        WHERE employeeid = doc_record.employeeid;
        
        -- Log the summary
        INSERT INTO system_audit_logs (event_name, details)
        VALUES ('MONTHLY_REPORT', 'Doctor ' || doc_record.name || ' is managing ' || patient_count || ' patients.');
        
    END LOOP;
    
    CLOSE doc_cursor;
END;
$$;

-----------------------------------------------------------
-- 5. TRANSACTION MANAGEMENT & ACID DEMONSTRATION
-----------------------------------------------------------
-- Example of using SAVEPOINTs
DO $$
BEGIN
    -- Savepoint 1
    INSERT INTO patients (name, age, gender) VALUES ('Test Transaction', 0, 'Other');
    SAVEPOINT patient_added;

    -- Intentional error check (mock)
    IF (SELECT COUNT(*) FROM patients WHERE name = 'Test Transaction') > 1 THEN
        ROLLBACK TO patient_added;
    END IF;

    COMMIT;
END;
$$;
