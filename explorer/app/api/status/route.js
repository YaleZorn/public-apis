import { mailConfigured } from "../../../server/mail.js";

export async function GET() {
  const hasDb = Boolean(process.env.DATABASE_URL?.trim());
  return Response.json({
    ok: true,
    storage: hasDb ? "postgres" : "memory",
    sampleData: !hasDb,
    mailConfigured: mailConfigured(),
  });
}