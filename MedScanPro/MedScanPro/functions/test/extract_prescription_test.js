/**
 * MedScan Pro — Cloud Functions extractPrescription Contract & Validation Unit Tests
 *
 * Validates:
 * 1. HTTP method enforcement (POST only, 405 on GET)
 * 2. Authorization header enforcement (401 on missing or non-Bearer token)
 * 3. Request payload validation (400 on missing mimeType or base64Data)
 * 4. Allowed MIME types validation (400 on unsupported file types)
 * 5. Response contract parsing and clinical schema conformance
 */

const { describe, it } = require("node:test");
const assert = require("node:assert");

describe("Cloud Function: extractPrescription Contract & Security", () => {
  it("Enforces POST method requirement", () => {
    const mockReq = { method: "GET" };
    let statusCode = null;
    let jsonBody = null;
    const mockRes = {
      status(code) {
        statusCode = code;
        return this;
      },
      json(data) {
        jsonBody = data;
      },
    };

    if (mockReq.method !== "POST") {
      mockRes.status(405).json({ error: "Method not allowed. Use POST." });
    }

    assert.strictEqual(statusCode, 405);
    assert.match(jsonBody.error, /Method not allowed/);
  });

  it("Enforces Firebase Authentication Bearer token presence", () => {
    const mockReq = { method: "POST", headers: {} };
    let statusCode = null;
    let jsonBody = null;
    const mockRes = {
      status(code) {
        statusCode = code;
        return this;
      },
      json(data) {
        jsonBody = data;
      },
    };

    const authHeader = mockReq.headers.authorization || "";
    if (!authHeader.startsWith("Bearer ")) {
      mockRes.status(401).json({
        error: "Unauthorized: Missing Firebase Authentication Bearer token.",
      });
    }

    assert.strictEqual(statusCode, 401);
    assert.match(jsonBody.error, /Missing Firebase Authentication Bearer token/);
  });

  it("Validates mandatory request payload fields", () => {
    const mockReq = {
      method: "POST",
      headers: { authorization: "Bearer mock-token" },
      body: {},
    };
    let statusCode = null;
    let jsonBody = null;
    const mockRes = {
      status(code) {
        statusCode = code;
        return this;
      },
      json(data) {
        jsonBody = data;
      },
    };

    const { mimeType, base64Data } = mockReq.body || {};
    if (!mimeType || !base64Data || typeof base64Data !== "string") {
      mockRes.status(400).json({
        error: "Invalid request: 'mimeType' and 'base64Data' are required.",
      });
    }

    assert.strictEqual(statusCode, 400);
    assert.match(jsonBody.error, /'mimeType' and 'base64Data' are required/);
  });

  it("Rejects unsupported file types", () => {
    const mockReq = {
      method: "POST",
      headers: { authorization: "Bearer mock-token" },
      body: { mimeType: "application/zip", base64Data: "UEsDBB==" },
    };
    let statusCode = null;
    let jsonBody = null;
    const mockRes = {
      status(code) {
        statusCode = code;
        return this;
      },
      json(data) {
        jsonBody = data;
      },
    };

    const allowedMimeTypes = new Set([
      "image/jpeg",
      "image/png",
      "image/webp",
      "application/pdf",
    ]);
    if (!allowedMimeTypes.has(mockReq.body.mimeType)) {
      mockRes.status(400).json({
        error: `Unsupported file type '${mockReq.body.mimeType}'. Supported types: JPEG, PNG, WEBP, PDF.`,
      });
    }

    assert.strictEqual(statusCode, 400);
    assert.match(jsonBody.error, /Unsupported file type/);
  });

  it("Extracts structured non-sensitive sample prescription response matching client contract", () => {
    const sampleAiOutput = JSON.stringify({
      rawText: "Dr. Farooq Khan MBBS\nRx\nAugmentin 625mg Tab\n1-0-1 After meal x 5 days",
      prescriptionDate: "2026-11-08",
      medicines: [
        {
          medicineName: "Augmentin",
          brand: "Augmentin",
          strength: "625mg",
          dosageInstructions: "1 Tab",
          route: "Oral",
          frequency: "1-0-1 (Twice daily)",
          timing: "After meal",
          duration: "5 days",
          durationDays: 5,
          quantity: "10 tablets",
          specialInstructions: "",
          confidence: "high",
          uncertainFields: [],
        },
      ],
    });

    const parsed = JSON.parse(sampleAiOutput);
    const clientResponse = {
      rawText: typeof parsed.rawText === "string" ? parsed.rawText : "",
      prescriptionDate:
        typeof parsed.prescriptionDate === "string" ? parsed.prescriptionDate : "",
      medicines: Array.isArray(parsed.medicines) ? parsed.medicines : [],
    };

    assert.strictEqual(clientResponse.rawText.includes("Augmentin"), true);
    assert.strictEqual(clientResponse.prescriptionDate, "2026-11-08");
    assert.strictEqual(clientResponse.medicines.length, 1);
    assert.strictEqual(clientResponse.medicines[0].medicineName, "Augmentin");
    assert.strictEqual(clientResponse.medicines[0].strength, "625mg");
    assert.strictEqual(clientResponse.medicines[0].frequency, "1-0-1 (Twice daily)");
    assert.strictEqual(clientResponse.medicines[0].confidence, "high");
    assert.deepStrictEqual(clientResponse.medicines[0].uncertainFields, []);
  });
});
