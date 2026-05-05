var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import express from "express";
import Log from "./logger.js";
import { PrismaClient } from './generated/prisma/client.js';
import { verifyToken } from './middlewares/verifyToken.js';
import CheckBADJSON from "./middlewares/JsonErrorChecker.js";
import cors from "cors";
// Initialize base Prisma Client
const basePrisma = new PrismaClient();
/**
 * Senior Developer Note:
 * We extend the Prisma client to support Row-Level Security (RLS).
 * The $withUser extension ensures that every database operation is wrapped
 * in a transaction that sets the 'app.current_employee_id' session variable.
 * This triggers the RLS policies defined in PostgreSQL.
 */
const prisma = basePrisma.$extends({
    client: {
        $withUser(employeeId) {
            return basePrisma.$extends({
                query: {
                    $allModels: {
                        $allOperations(_a) {
                            return __awaiter(this, arguments, void 0, function* ({ args, query }) {
                                // Run in a transaction to ensure set_config and query share the same connection
                                const [, result] = yield basePrisma.$transaction([
                                    basePrisma.$executeRawUnsafe(`SELECT set_config('app.current_employee_id', '${employeeId}', true)`),
                                    query(args)
                                ]);
                                return result;
                            });
                        }
                    }
                }
            });
        }
    }
});
const app = express();
const router = express.Router();
app.use(express.json());
app.use(cors());
//AUTH URL
/////////////////////////////////////////////////////////
const auth_url = "http://auth:3000/login"; ///////////////
/////////////////////////////////////////////////////////
router.get("/", (req, res) => {
    Log("/", "GET", 200);
    res.send("HALO");
});
router.post("/login", (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    Log("/login", "POST", 200);
    const { email, password } = req.body;
    if (!email || !password) {
        return res.status(400).json({
            error: "Bad Payload."
        });
    }
    try {
        const Response = yield fetch(auth_url, {
            method: "POST",
            headers: {
                "Content-Type": "application/json"
            },
            body: JSON.stringify({ email, password })
        });
        if (!Response.ok) {
            console.error("Auth container responded with error:", Response.status);
            return res.status(500).json({ error: "Auth container error." });
        }
        const json = yield Response.json();
        return res.json(json);
    }
    catch (e) {
        console.error("Some problem occurred while contacting auth container. Error:", e);
        return res.status(500).json({
            error: "Unable to login, Some error occurred in backend.",
            details: e
        });
    }
}));
router.get("/patients", verifyToken, (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const employeeid = req.user.employeeid;
        // Use the secure RLS-aware Prisma client
        const securePrisma = prisma.$withUser(employeeid);
        // Notice we no longer need complex 'where' clauses to filter by employeeid.
        // The RLS policy on the database handles the filtering automatically!
        const patients = yield securePrisma.patient.findMany({
            include: {
                reports: true
            }
        });
        return res.json({ patients });
    }
    catch (err) {
        console.error("Error fetching patients:", err);
        res.status(500).json({ error: "Internal server error" });
    }
}));
router.get("/patient/:id", verifyToken, (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    const patientId = parseInt(req.params.id);
    if (isNaN(patientId)) {
        return res.status(400).json({ error: "Invalid patient ID" });
    }
    try {
        const employeeid = req.user.employeeid;
        const securePrisma = prisma.$withUser(employeeid);
        const patient = yield securePrisma.patient.findUnique({
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
        if (!patient) {
            // If RLS filters the record, findUnique will return null, 
            // which is perfect for security (no distinguishability between "forbidden" and "not found").
            return res.status(404).json({ error: "Patient not found or access denied" });
        }
        return res.json({ patient });
    }
    catch (err) {
        console.error("Error fetching patient:", err);
        return res.status(500).json({ error: "Internal server error" });
    }
}));
router.get("/account", verifyToken, (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    const employeeid = req.user.employeeid;
    try {
        const securePrisma = prisma.$withUser(employeeid);
        // RLS on the 'employees' table will ensure only this employee's data is returned
        const doctor = yield securePrisma.employee.findUnique({
            where: { employeeid },
            select: {
                employeeid: true,
                name: true,
                email: true,
                phone_number: true,
                role: true,
                prescribed: {
                    select: {
                        patient: {
                            select: {
                                patientid: true,
                                name: true,
                                age: true,
                                gender: true
                            }
                        }
                    }
                }
            }
        });
        if (!doctor) {
            return res.status(404).json({ error: "Employee not found" });
        }
        res.json({ account: doctor });
    }
    catch (err) {
        console.error("Error in /account:", err);
        res.status(500).json({ error: "Internal server error" });
    }
}));
// NOVELTY FEATURE: Medical History (Time Machine)
// This endpoint retrieves all past versions of a patient's record.
router.get("/patient/:id/history", verifyToken, (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    const patientId = parseInt(req.params.id);
    if (isNaN(patientId)) {
        return res.status(400).json({ error: "Invalid patient ID" });
    }
    try {
        const employeeid = req.user.employeeid;
        const securePrisma = prisma.$withUser(employeeid);
        // Fetch history from the patient_history table
        // RLS on patient_history ensures only authorized doctors see this.
        const history = yield securePrisma.patientHistory.findMany({
            where: { patientid: patientId },
            orderBy: { changed_at: 'desc' }
        });
        return res.json({
            patient_id: patientId,
            version_count: history.length,
            history
        });
    }
    catch (err) {
        console.error("Error fetching patient history:", err);
        return res.status(500).json({ error: "Internal server error" });
    }
}));
// DBMS PROJECT INTEGRATION: Analytics & Integrity Checks
// This route demonstrates the use of the SQL VIEW 'health_integrity_audit'
router.get("/analytics/integrity", verifyToken, (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        const integrityReport = yield prisma.$queryRaw `SELECT * FROM health_integrity_audit`;
        return res.json({ integrityReport });
    }
    catch (err) {
        console.error("Integrity audit failed:", err);
        return res.status(500).json({ error: "Failed to fetch integrity report. Ensure rls_setup.sql has been run." });
    }
}));
// DBMS PROJECT INTEGRATION: Stored Procedure Call
// This route triggers the 'sp_generate_doctor_activity_report' procedure
router.post("/analytics/refresh-stats", verifyToken, (req, res) => __awaiter(void 0, void 0, void 0, function* () {
    try {
        yield prisma.$executeRaw `CALL sp_generate_doctor_activity_report()`;
        return res.json({ message: "Activity report generated in system_audit_logs." });
    }
    catch (err) {
        console.error("Stats refresh failed:", err);
        return res.status(500).json({ error: "Failed to run procedure. Ensure dbms_implementation.sql has been run." });
    }
}));
/////////Mounting all the middlewares//////////
// Mounting JSON Checker
app.use("/", CheckBADJSON);
// MOunting router
app.use("/", router);
//////////////////////////////////////////////
const port = process.env.BACKEND_PORT || 8080;
app.listen(port, () => {
    console.log(`Backend running on port ${port}`);
});
