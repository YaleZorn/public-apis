import { requireAdmin } from "../../../../../server/adminAuth.js";
import { sql } from "../../../../../server/db.js";

export async function PATCH(request, { params }) {
  const auth = await requireAdmin(request);
  if (!auth.ok) {
    return Response.json({ error: auth.error }, { status: auth.status });
  }

  const id = Number(params?.id);
  if (!Number.isFinite(id) || id <= 0) {
    return Response.json({ error: "invalid_id" }, { status: 400 });
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return Response.json({ error: "invalid_json" }, { status: 400 });
  }

  const status = String(body.status || "").trim().toLowerCase();
  if (!["new", "read", "done"].includes(status)) {
    return Response.json({ error: "invalid_status" }, { status: 400 });
  }

  const rows = await sql(
    "update feedback set status = $2 where id = $1 returning id, status",
    [id, status],
  );
  if (!rows.length) {
    return Response.json({ error: "not_found" }, { status: 404 });
  }
  return Response.json({ ok: true, item: rows[0] });
}
