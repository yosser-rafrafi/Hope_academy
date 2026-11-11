// Cloud Function that writes parent-friendly reports with Claude.
// The API key lives ONLY here (Secret Manager), never in the Flutter app.
//
// Deploy:
//   firebase functions:secrets:set ANTHROPIC_API_KEY
//   firebase deploy --only functions:generateReport
// Then build the app with:
//   --dart-define=AI_REPORT_ENDPOINT=<function url>

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

admin.initializeApp();
const ANTHROPIC_API_KEY = defineSecret('ANTHROPIC_API_KEY');

const LANGS = { en: 'English', fr: 'French', ar: 'Arabic' };

const SYSTEM = `You write short progress reports for parents of children with special needs at Hope Academy.
Rules:
- Warm, respectful, strength-based. Celebrate effort and small steps.
- NEVER compare the child to other children or to a norm. Never use words like "delay", "behind", "deficit", "problem".
- Do not diagnose and do not give medical advice.
- Use ONLY facts present in the data. Never invent events, scores or quotes.
- If a day was difficult, say so gently and mention the team is supporting the child.
- Address the parent directly, use the child's first name, end with a warm closing from "The Hope Academy Team".
- Plain text, a few emojis at most, no markdown headings.`;

exports.generateReport = onRequest(
  { secrets: [ANTHROPIC_API_KEY], cors: true, timeoutSeconds: 60, memory: '256MiB' },
  async (req, res) => {
    try {
      if (req.method !== 'POST') return res.status(405).send('POST only');

      // 1. Only signed-in app users may call this.
      const token = (req.get('Authorization') || '').replace('Bearer ', '');
      await admin.auth().verifyIdToken(token);

      // 2. Validate input (and keep the prompt small).
      const { kind, language, childFirstName, activities } = req.body || {};
      if (!['daily', 'weekly'].includes(kind) || !Array.isArray(activities) ||
          activities.length === 0 || activities.length > 40 || !childFirstName) {
        return res.status(400).send('Bad request');
      }

      const lang = LANGS[language] || 'English';
      const prompt =
        `Write a ${kind === 'daily' ? 'daily report' : 'weekly summary'} in ${lang}.\n` +
        `Child: ${String(childFirstName).slice(0, 40)}\n` +
        `Data (JSON):\n${JSON.stringify(activities).slice(0, 12000)}`;

      const r = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          'x-api-key': ANTHROPIC_API_KEY.value(),
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: process.env.AI_MODEL || 'claude-sonnet-5-5',
          max_tokens: 900,
          system: SYSTEM,
          messages: [{ role: 'user', content: prompt }],
        }),
      });
      if (!r.ok) return res.status(502).send('AI error');

      const data = await r.json();
      const report = (data.content || []).map((b) => b.text || '').join('').trim();
      if (!report) return res.status(502).send('Empty report');
      return res.json({ report });
    } catch (e) {
      console.error(e);
      return res.status(401).send('Unauthorized');
    }
  }
);
