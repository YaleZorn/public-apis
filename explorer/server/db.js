import { readdir, readFile } from "node:fs/promises";
import { PGlite } from "@electric-sql/pglite";
import pg from "pg";

const databaseUrl = process.env.DATABASE_URL?.trim() ?? "";
const globalStore = globalThis;

export async function sql(text, params = []) {
  if (databaseUrl !== "") {
    globalStore.__stackpickPgPool ??= new pg.Pool({
      connectionString: databaseUrl,
      max: 5,
    });
    return (await globalStore.__stackpickPgPool.query(text, params)).rows;
  }

  globalStore.__stackpickPglite ??= startLocal().catch((error) => {
    globalStore.__stackpickPglite = undefined;
    throw error;
  });
  return (await (await globalStore.__stackpickPglite).query(text, params)).rows;
}

async function startLocal() {
  const db = new PGlite();
  const files = (await readdir("migrations").catch(() => []))
    .filter((f) => f.endsWith(".sql"))
    .sort();
  for (const file of files) {
    await db.exec(await readFile(`migrations/${file}`, "utf8"));
  }
  return db;
}
