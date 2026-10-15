const sensitiveKeys = new Set([
  "authorization",
  "cookie",
  "password",
  "token",
  "accessToken",
  "jwt",
  "secret",
  "databasePassword"
]);

function sanitizeLogFields(value, key = "") {
  if (sensitiveKeys.has(key)) return "[REDACTED]";
  if (Buffer.isBuffer(value)) return `[Buffer ${value.length} bytes]`;
  if (Array.isArray(value)) return value.map((item) => sanitizeLogFields(item));
  if (!value || typeof value !== "object") return value;

  return Object.fromEntries(
    Object.entries(value).map(([entryKey, entryValue]) => [
      entryKey,
      sanitizeLogFields(entryValue, entryKey)
    ])
  );
}

module.exports = { sanitizeLogFields };
