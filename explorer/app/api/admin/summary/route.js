import { requireAdmin } from "../../../../server/adminAuth.js";
import { sql } from "../../../../server/db.js";

export async function GET(request) {
  const auth = await requireAdmin(request);
  if (!auth.ok) {
    return Response.json({ error: auth.error }, { status: auth.status });
  }

  const [waitlist, confirmed, stacks, feedback, mail] = await Promise.all([
    sql("select count(*)::int as count from waitlist"),
    sql("select count(*)::int as count from waitlist where confirmed_at is not null"),
    sql(
      "select count(*)::int as count from stacks where expires_at is null or expires_at > now()",
    ),
    sql("select count(*)::int as count from feedback where status = 'new'"),
    sql(
      "select coalesce(sum(sent),0)::int as sent from mail_quota where day = current_date",
    ),
  ]);

  const recentFeedback = await sql(
    `select id, created_at, email, category, message, status
     from feedback
     order by created_at desc
     limit 25`,
  );

  return Response.json({
    ok: true,
    via: auth.via,
    stats: {
      waitlist: waitlist[0]?.count || 0,
      accounts: waitlist[0]?.count || 0,
      confirmed: confirmed[0]?.count || 0,
      activeStacks: stacks[0]?.count || 0,
      newFeedback: feedback[0]?.count || 0,
      mailSentToday: mail[0]?.sent || 0,
    },
    feedback: recentFeedback,
  });
}
