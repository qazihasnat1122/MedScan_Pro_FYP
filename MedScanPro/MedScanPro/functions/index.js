/**
 * MedScan Pro — Secure Prescription Extraction Backend (Firebase Cloud Functions v2)
 *
 * SECURITY GUARANTEES:
 * 1. The Gemini API key is stored strictly server-side via environment configuration
 *    (`functions/.env` or Firebase Secret Manager `GEMINI_API_KEY`) and is NEVER exposed
 *    in client source code or version control.
 * 2. Every request must include a valid Firebase Auth ID token (`Authorization: Bearer <token>`).
 * 3. Prescription images, PDFs, extracted text, and tokens are NEVER logged.
 * 4. Gemini is instructed to perform strict visual extraction only — never diagnosing,
 *    recommending treatment, or inventing missing medicine names, doses, times, or durations.
 */

const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const EXTRACTION_SYSTEM_PROMPT = `You are a clinical prescription text extractor for a medication safety app.
Your ONLY task is to extract visible prescription text and structured medication fields from the provided prescription image or PDF document.

STRICT SAFETY RULES:
1. Extract ONLY what is visibly written on the prescription. Do NOT diagnose conditions, recommend treatments, check drug interactions, or provide medical advice.
2. NEVER invent, guess, or assume medicine names, strengths, dosages, routes, frequencies, clock times, durations, quantities, or dates.
3. If any field is illegible, missing, cut off, or uncertain, leave its value as an empty string "" (or null for numeric/boolean fields) and set "confidence" to "low" (or "medium" if partially legible) and add the field name to "uncertainFields".
4. Ignore hospital logos, doctor degrees/qualifications, clinic phone numbers, and promotional footers when building the medicines list.

Return strictly valid JSON matching this schema:
{
  "rawText": "Full visible prescription text transcribed faithfully",
  "prescriptionDate": "Visible date on prescription or empty string",
  "medicines": [
    {
      "medicineName": "Generic or main written medicine name, or empty string if illegible",
      "brand": "Brand name if explicitly written, else empty string",
      "strength": "Visible strength e.g. 500mg, or empty string if missing/unclear",
      "dosageInstructions": "Visible dose instruction e.g. 1 tablet, 5ml, or empty string",
      "route": "Visible route/form e.g. Oral, Tablet, Capsule, Syrup, Topical, or empty string",
      "frequency": "Visible frequency exactly as written e.g. Twice daily, 1-0-1, PRN / as needed, or empty string",
      "timing": "Visible meal/timing note e.g. After meal, Before breakfast, or empty string",
      "duration": "Visible duration as written e.g. 5 days, 2 weeks, or empty string",
      "durationDays": null,
      "quantity": "Visible total quantity to dispense e.g. 10 tablets, 1 bottle, or empty string",
      "specialInstructions": "Any special note, tapering instruction, or warning written on the prescription, or empty string",
      "confidence": "high | medium | low",
      "uncertainFields": ["strength", "frequency"]
    }
  ]
}`;

exports.extractPrescription = onRequest(
  {
    cors: true,
    maxInstances: 10,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method not allowed. Use POST." });
    }

    // 1. Verify Firebase Auth ID token
    const authHeader = req.headers.authorization || "";
    if (!authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        error: "Unauthorized: Missing Firebase Authentication Bearer token.",
      });
    }

    const idToken = authHeader.substring("Bearer ".length).trim();
    try {
      await admin.auth().verifyIdToken(idToken);
    } catch (_) {
      return res.status(401).json({
        error: "Unauthorized: Invalid or expired Firebase Authentication token.",
      });
    }

    // 2. Verify server-side GEMINI_API_KEY configuration
    const apiKey = (process.env.GEMINI_API_KEY || "").trim();
    if (!apiKey) {
      return res.status(503).json({
        error: "Server configuration error: GEMINI_API_KEY secret is not configured on the backend.",
      });
    }

    // 3. Validate request payload (without logging sensitive content)
    const { mimeType, base64Data, additionalPagesBase64 } = req.body || {};
    if (!mimeType || !base64Data || typeof base64Data !== "string") {
      return res.status(400).json({
        error: "Invalid request: 'mimeType' and 'base64Data' are required.",
      });
    }

    const allowedMimeTypes = new Set([
      "image/jpeg",
      "image/png",
      "image/webp",
      "application/pdf",
    ]);
    if (!allowedMimeTypes.has(mimeType)) {
      return res.status(400).json({
        error: `Unsupported file type '${mimeType}'. Supported types: JPEG, PNG, WEBP, PDF.`,
      });
    }

    try {
      const parts = [
        { text: EXTRACTION_SYSTEM_PROMPT },
        {
          inlineData: {
            mimeType,
            data: base64Data,
          },
        },
      ];

      if (Array.isArray(additionalPagesBase64)) {
        for (const pageB64 of additionalPagesBase64.slice(0, 4)) {
          if (typeof pageB64 === "string" && pageB64.length > 0) {
            parts.push({
              inlineData: {
                mimeType: "image/png",
                data: pageB64,
              },
            });
          }
        }
      }

      const geminiModel = (process.env.GEMINI_MODEL || "gemini-flash-latest").trim();
      const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(geminiModel)}:generateContent?key=${encodeURIComponent(apiKey)}`;
      const geminiResponse = await fetch(geminiUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          contents: [{ role: "user", parts }],
          generationConfig: {
            temperature: 0.0,
            responseMimeType: "application/json",
          },
        }),
      });

      if (!geminiResponse.ok) {
        return res.status(502).json({
          error: `Upstream AI extraction service returned HTTP ${geminiResponse.status}.`,
        });
      }

      const geminiPayload = await geminiResponse.json();
      const rawJsonText =
        geminiPayload?.candidates?.[0]?.content?.parts?.[0]?.text || "";

      if (!rawJsonText) {
        return res.status(422).json({
          error: "No readable prescription content could be extracted from the document.",
        });
      }

      let parsed;
      try {
        parsed = JSON.parse(rawJsonText);
      } catch (_) {
        return res.status(502).json({
          error: "AI service returned malformed structured output.",
        });
      }

      return res.status(200).json({
        rawText: typeof parsed.rawText === "string" ? parsed.rawText : "",
        prescriptionDate:
          typeof parsed.prescriptionDate === "string" ? parsed.prescriptionDate : "",
        medicines: Array.isArray(parsed.medicines) ? parsed.medicines : [],
      });
    } catch (_) {
      return res.status(500).json({
        error: "Prescription extraction failed due to an internal server error.",
      });
    }
  }
);

exports.chatConsultant = onRequest(
  {
    cors: true,
    maxInstances: 10,
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      return res.status(405).json({ error: "Method not allowed. Use POST." });
    }

    // 1. Verify Firebase Auth ID token
    const authHeader = req.headers.authorization || "";
    if (!authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        error: "Unauthorized: Missing Firebase Authentication Bearer token.",
      });
    }

    const idToken = authHeader.substring("Bearer ".length).trim();
    try {
      await admin.auth().verifyIdToken(idToken);
    } catch (_) {
      return res.status(401).json({
        error: "Unauthorized: Invalid or expired Firebase Authentication token.",
      });
    }

    // 2. Read server-side API key (CHAT_API_KEY or GEMINI_API_KEY)
    const apiKey = (process.env.CHAT_API_KEY || process.env.GEMINI_API_KEY || "").trim();
    if (!apiKey) {
      return res.status(503).json({
        error: "Server configuration error: AI API key secret is not configured on the backend.",
      });
    }

    const { messages, userQuery, ragContext, systemInstruction } = req.body || {};
    if (!userQuery && (!messages || !messages.length)) {
      return res.status(400).json({ error: "Missing userQuery or messages in request body." });
    }

    try {
      const isSk = apiKey.startsWith("sk-");
      let replyText = "";

      if (isSk) {
        // OpenAI / OpenRouter Chat Completions standard
        const chatUrl = process.env.CHAT_API_URL || "https://api.openai.com/v1/chat/completions";
        const model = process.env.CHAT_MODEL || "gpt-4o-mini";
        const formattedMessages = messages || [
          { role: "system", content: systemInstruction || "You are MedScan Pro's Health and Medicine Information Assistant." },
          { role: "user", content: userQuery || "" },
        ];

        const openAiResp = await fetch(chatUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${apiKey}`,
          },
          body: JSON.stringify({
            model,
            messages: formattedMessages,
            temperature: 0.2,
            max_tokens: 1000,
          }),
        });

        if (!openAiResp.ok) {
          return res.status(502).json({
            error: `Upstream AI service returned HTTP ${openAiResp.status}.`,
          });
        }

        const data = await openAiResp.json();
        replyText = data?.choices?.[0]?.message?.content || "";
      } else {
        // Google Gemini generateContent
        const geminiModel = (process.env.CHAT_MODEL || "gemini-3.8-flash").trim();
        const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(geminiModel)}:generateContent?key=${encodeURIComponent(apiKey)}`;

        const geminiResp = await fetch(geminiUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-goog-api-key": apiKey,
          },
          body: JSON.stringify({
            contents: [{ role: "user", parts: [{ text: `${systemInstruction}\n\n${userQuery}` }] }],
            generationConfig: {
              temperature: 0.2,
              maxOutputTokens: 1000,
            },
          }),
        });

        if (!geminiResp.ok) {
          return res.status(502).json({
            error: `Upstream AI service returned HTTP ${geminiResp.status}.`,
          });
        }

        const data = await geminiResp.json();
        replyText = data?.candidates?.[0]?.content?.parts?.[0]?.text || "";
      }

      return res.status(200).json({ reply: replyText });
    } catch (_) {
      return res.status(500).json({
        error: "AI consulting request failed due to an internal server error.",
      });
    }
  }
);
