import { readFile } from "node:fs/promises";
import path from "node:path";

let cache;

export async function loadCatalog() {
  if (cache) return cache;
  const file = path.join(process.cwd(), "public", "data", "apis.json");
  cache = JSON.parse(await readFile(file, "utf8"));
  return cache;
}

export async function catalogUrlSet() {
  const data = await loadCatalog();
  return new Set(data.apis.map((a) => a.url));
}

export async function findApisByIds(ids) {
  const data = await loadCatalog();
  const wanted = new Set(ids);
  return data.apis.filter((a) => wanted.has(a.id));
}
