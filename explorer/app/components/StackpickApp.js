"use client";

import { useCallback, useEffect, useMemo, useState } from "react";

const PAGE_SIZE = 40;
const FREE_STACK_LIMIT = 5;
const PRO_STACK_LIMIT = 25;
const STORAGE_STACK = "stackpick.stack.v1";
const STORAGE_PRO = "stackpick.pro.v1";
const STORAGE_PRO_TOKEN = "stackpick.pro.token.v1";

function loadJson(key, fallback) {
  try {
    return JSON.parse(localStorage.getItem(key) || JSON.stringify(fallback));
  } catch {
    return fallback;
  }
}

export function StackpickApp() {
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [q, setQ] = useState("");
  const [category, setCategory] = useState("");
  const [auth, setAuth] = useState("");
  const [https, setHttps] = useState("");
  const [cors, setCors] = useState("");
  const [visible, setVisible] = useState(PAGE_SIZE);
  const [stack, setStack] = useState([]);
  const [proEmail, setProEmail] = useState("");
  const [proToken, setProToken] = useState("");
  const [panelOpen, setPanelOpen] = useState(false);
  const [waitlistEmail, setWaitlistEmail] = useState("");
  const [waitlistNote, setWaitlistNote] = useState("");
  const [waitlistBusy, setWaitlistBusy] = useState(false);
  const [shareNote, setShareNote] = useState("");
  const [healthNote, setHealthNote] = useState("");
  const [healthRows, setHealthRows] = useState([]);
  const [busy, setBusy] = useState("");
  const [sampleData, setSampleData] = useState(false);
  const [mailConfigured, setMailConfigured] = useState(false);

  const isPro = Boolean(proEmail && proToken);
  const stackLimit = isPro ? PRO_STACK_LIMIT : FREE_STACK_LIMIT;

  async function confirmWaitlistToken(confirmToken) {
    const res = await fetch("/api/waitlist/confirm", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token: confirmToken }),
    });
    const payload = await res.json().catch(() => ({}));
    if (!res.ok || !payload.token || !payload.email) {
      throw new Error(payload.error || "confirm_failed");
    }
    localStorage.setItem(STORAGE_PRO, payload.email);
    localStorage.setItem(STORAGE_PRO_TOKEN, payload.token);
    setProEmail(payload.email);
    setProToken(payload.token);
    setWaitlistNote(`Email confirmed for ${payload.email}. Pro tools are unlocked on this device.`);
    return payload;
  }

  useEffect(() => {
    const onKey = (e) => {
      if (e.key === "Escape") setPanelOpen(false);
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  useEffect(() => {
    setStack(loadJson(STORAGE_STACK, []));
    const savedPro = localStorage.getItem(STORAGE_PRO) || "";
    const savedToken = localStorage.getItem(STORAGE_PRO_TOKEN) || "";
    if (savedPro && savedToken) {
      setProEmail(savedPro);
      setProToken(savedToken);
      setWaitlistNote(`Pro unlocked for ${savedPro}.`);
    } else if (savedPro && !savedToken) {
      localStorage.removeItem(STORAGE_PRO);
      setWaitlistNote("Please rejoin the waitlist to refresh Pro access.");
    }

    const params = new URLSearchParams(window.location.search);
    const code = params.get("stack");
    const confirm = params.get("confirm");
    fetch("/api/status")
      .then((res) => res.json())
      .then((status) => {
        setSampleData(Boolean(status.sampleData));
        setMailConfigured(Boolean(status.mailConfigured));
      })
      .catch(() => setSampleData(true));
    fetch("/data/apis.json")
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json();
      })
      .then(async (catalog) => {
        setData(catalog);
        if (confirm) {
          try {
            await confirmWaitlistToken(confirm);
            const next = new URL(window.location.href);
            next.searchParams.delete("confirm");
            window.history.replaceState({}, "", next.pathname + next.search);
          } catch {
            setWaitlistNote("Confirmation link invalid or expired. Request a new waitlist email.");
          }
        }
        if (code) {
          try {
            const res = await fetch(`/api/stacks/${encodeURIComponent(code)}`);
            if (res.ok) {
              const payload = await res.json();
              const items = Array.isArray(payload.items) ? payload.items : [];
              setStack(items);
              localStorage.setItem(STORAGE_STACK, JSON.stringify(items));
              setShareNote(`Loaded shared stack ${code} (${items.length} APIs).`);
              setPanelOpen(true);
            } else {
              setShareNote("Shared stack not found.");
            }
          } catch {
            setShareNote("Could not load shared stack.");
          }
        }
      })
      .catch((err) => setError(err.message || "Failed to load catalog."));
  }, []);

  const persistStack = useCallback((updater) => {
    setStack((prev) => {
      const next = typeof updater === "function" ? updater(prev) : updater;
      localStorage.setItem(STORAGE_STACK, JSON.stringify(next));
      return next;
    });
  }, []);

  const filtered = useMemo(() => {
    if (!data) return [];
    const query = q.trim().toLowerCase();
    return data.apis.filter((api) => {
      if (category && api.category !== category) return false;
      if (auth && api.auth !== auth) return false;
      if (https === "yes" && !api.https) return false;
      if (https === "no" && api.https) return false;
      if (cors && api.cors !== cors) return false;
      if (!query) return true;
      return `${api.name} ${api.description} ${api.category}`.toLowerCase().includes(query);
    });
  }, [data, q, category, auth, https, cors]);

  const slice = filtered.slice(0, visible);

  function toggleStack(api) {
    let blocked = false;
    persistStack((prev) => {
      const idx = prev.findIndex((item) => item.id === api.id);
      if (idx >= 0) {
        return prev.filter((item) => item.id !== api.id);
      }
      if (prev.length >= stackLimit) {
        blocked = true;
        return prev;
      }
      return [
        ...prev,
        { id: api.id, name: api.name, url: api.url, category: api.category },
      ];
    });
    if (blocked) {
      setPanelOpen(true);
      setWaitlistNote(
        isPro
          ? `Pro shortlist is limited to ${PRO_STACK_LIMIT} APIs.`
          : "Free shortlist is limited to 5 APIs. Join Pro waitlist to raise the cap and unlock export/health.",
      );
      document.getElementById("pro")?.scrollIntoView({ behavior: "smooth" });
    }
  }

  async function joinWaitlist(event) {
    event.preventDefault();
    const email = waitlistEmail.trim().toLowerCase();
    if (!email) return;
    setWaitlistBusy(true);
    setWaitlistNote("");
    try {
      const form = new FormData(event.currentTarget);
      const res = await fetch("/api/waitlist", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          email,
          source: "web",
          company: form.get("company") || "",
        }),
      });
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) {
        if (payload.error === "rate_limited") {
          setWaitlistNote("Too many attempts. Try again in a few minutes.");
        } else if (payload.error === "mail_failed") {
          const mailHints = {
            auth: "Resend rejected the API key. Check RESEND_API_KEY in app secrets.",
            from: "Sender address is not verified in Resend. Set RESEND_FROM to onboarding@resend.dev or a verified domain.",
            test_recipient:
              "Resend test mode only delivers to your Resend account email until you verify a domain.",
            provider: "Could not send confirmation email. Try again later.",
          };
          setWaitlistNote(mailHints[payload.reason] || mailHints.provider);
        } else {
          setWaitlistNote("Could not join waitlist. Check the email and retry.");
        }
        return;
      }

      setWaitlistEmail("");
      if (payload.delivery === "email") {
        setWaitlistNote(`Check ${email} for a confirmation link to unlock Pro.`);
        return;
      }
      if (payload.delivery === "sample" && payload.sampleConfirmToken) {
        await confirmWaitlistToken(payload.sampleConfirmToken);
        return;
      }
      setWaitlistNote(
        "You're on the list. Add the RESEND_API_KEY app secret, then request confirmation again to unlock Pro.",
      );
    } catch {
      setWaitlistNote("Network error joining waitlist.");
    } finally {
      setWaitlistBusy(false);
    }
  }

  function exportStack(format) {
    if (!isPro) {
      setWaitlistNote("Export unlocks after you join the Pro waitlist.");
      document.getElementById("pro")?.scrollIntoView({ behavior: "smooth" });
      setPanelOpen(false);
      return;
    }
    if (!stack.length) {
      setShareNote("Add APIs to your stack before exporting.");
      return;
    }
    if (format === "json") {
      downloadBlob(
        `stackpick-${Date.now()}.json`,
        JSON.stringify({ exportedAt: new Date().toISOString(), items: stack }, null, 2),
        "application/json",
      );
      return;
    }
    const header = "name,category,url,id\n";
    const rows = stack
      .map((item) =>
        [item.name, item.category, item.url, item.id]
          .map((v) => `"${String(v).replaceAll('"', '""')}"`)
          .join(","),
      )
      .join("\n");
    downloadBlob(`stackpick-${Date.now()}.csv`, header + rows, "text/csv");
  }

  async function shareStack() {
    if (!stack.length) {
      setShareNote("Add APIs before sharing.");
      return;
    }
    setBusy("share");
    setShareNote("");
    try {
      const res = await fetch("/api/stacks", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ ids: stack.map((item) => item.id) }),
      });
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) {
        setShareNote(
          payload.error === "rate_limited"
            ? "Too many shares. Try again shortly."
            : payload.error === "capacity"
              ? "Share capacity is full. Try again later."
              : "Could not create share link.",
        );
        return;
      }
      const url = `${window.location.origin}/?stack=${payload.code}`;
      await navigator.clipboard?.writeText(url).catch(() => {});
      setShareNote(`Share link copied: ${url}`);
      window.history.replaceState({}, "", `?stack=${payload.code}`);
    } catch {
      setShareNote("Network error creating share link.");
    } finally {
      setBusy("");
    }
  }

  async function runHealth() {
    if (!isPro) {
      setWaitlistNote("Health checks unlock after you join the Pro waitlist.");
      document.getElementById("pro")?.scrollIntoView({ behavior: "smooth" });
      return;
    }
    if (!stack.length) {
      setHealthNote("Add APIs before running health checks.");
      return;
    }
    setBusy("health");
    setHealthNote("Checking endpoints…");
    setHealthRows([]);
    try {
      const res = await fetch("/api/health", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-stackpick-token": proToken,
        },
        body: JSON.stringify({
          ids: stack.slice(0, 5).map((item) => item.id),
          token: proToken,
        }),
      });
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) {
        setHealthNote(
          payload.error === "rate_limited"
            ? "Health check rate limited. Try again shortly."
            : payload.error === "pro_required"
              ? "Pro token expired. Rejoin the waitlist to refresh access."
              : "Health check failed.",
        );
        return;
      }
      setHealthRows(payload.results || []);
      const ok = (payload.results || []).filter((r) => r.ok).length;
      setHealthNote(`Checked ${payload.results?.length || 0} endpoints · ${ok} reachable.`);
    } catch {
      setHealthNote("Network error during health check.");
    } finally {
      setBusy("");
    }
  }

  if (error) {
    return (
      <main className="hero">
        <h1>Stackpick</h1>
        <p className="lede">Failed to load catalog: {error}</p>
      </main>
    );
  }

  if (!data) {
    return (
      <main className="hero">
        <h1>Stackpick</h1>
        <p className="lede">Loading catalog…</p>
      </main>
    );
  }

  const partners = data.featuredPartners?.length
    ? data.featuredPartners
    : [
        {
          name: "APILayer Suite",
          url: "https://apilayer.com/?utm_source=Github&utm_medium=Referral&utm_campaign=Public-apis-repo",
          description: "One account, one dashboard, production REST APIs.",
          label: "Partner",
        },
      ];

  return (
    <>
      <div className="blueprint-grid" aria-hidden="true" />
      <header className="topbar">
        <a className="brand" href="#top">
          Stackpick
        </a>
        <nav className="topnav">
          <a href="#catalog">Catalog</a>
          <a href="#partners">Partners</a>
          <a href="#pro">Pro</a>
          <button
            type="button"
            className="stack-btn"
            onClick={() => setPanelOpen(true)}
            aria-controls="stack-panel"
          >
            Stack <span>{stack.length}</span>
          </button>
        </nav>
      </header>

      <main id="top">
        <section className="hero">
          <p className="eyebrow">Public APIs · curated · searchable</p>
          <h1>Stackpick</h1>
          <p className="lede">
            Stop scrolling a 2,000-line README. Filter the catalog, shortlist APIs, export, share, and
            spot-check health.
          </p>
          <div className="cta-row">
            <a className="btn primary" href="#catalog">
              Browse catalog
            </a>
            <button
              type="button"
              className="btn ghost"
              onClick={() => document.getElementById("pro")?.scrollIntoView({ behavior: "smooth" })}
            >
              {isPro ? "Pro unlocked" : "Join Pro waitlist"}
            </button>
          </div>
        </section>

        <section className="partners" id="partners" aria-labelledby="partners-title">
          <div className="section-head">
            <h2 id="partners-title">Partner APIs</h2>
            <p>
              Production-grade options when free endpoints are not enough. Clearly labeled referrals.
            </p>
          </div>
          <div className="partner-track">
            {partners.map((p) => (
              <a
                key={p.name + p.url}
                className="partner-item"
                href={p.url}
                target="_blank"
                rel="noopener noreferrer sponsored"
              >
                <span className="tag">{p.label || "Partner"}</span>
                <strong>{p.name}</strong>
                <span>{p.description}</span>
              </a>
            ))}
          </div>
        </section>

        <section className="catalog" id="catalog" aria-labelledby="catalog-title">
          <div className="section-head">
            <h2 id="catalog-title">Catalog</h2>
            <p>
              {filtered.length.toLocaleString()} APIs match · showing {slice.length}
              {isPro ? " · Pro" : " · Free"}
            </p>
          </div>

          <form className="filters" role="search" onSubmit={(e) => e.preventDefault()}>
            <label className="search-field">
              <span className="sr-only">Search APIs</span>
              <input
                type="search"
                value={q}
                onChange={(e) => {
                  setQ(e.target.value);
                  setVisible(PAGE_SIZE);
                }}
                placeholder="Search name, description, category…"
                autoComplete="off"
              />
            </label>
            <label>
              Category
              <select
                value={category}
                onChange={(e) => {
                  setCategory(e.target.value);
                  setVisible(PAGE_SIZE);
                }}
              >
                <option value="">All</option>
                {data.categories.map((cat) => (
                  <option key={cat} value={cat}>
                    {cat}
                  </option>
                ))}
              </select>
            </label>
            <label>
              Auth
              <select
                value={auth}
                onChange={(e) => {
                  setAuth(e.target.value);
                  setVisible(PAGE_SIZE);
                }}
              >
                <option value="">All</option>
                <option value="No">None</option>
                <option value="apiKey">API key</option>
                <option value="OAuth">OAuth</option>
                <option value="X-Mashape-Key">Mashape</option>
                <option value="User-Agent">User-Agent</option>
              </select>
            </label>
            <label>
              HTTPS
              <select
                value={https}
                onChange={(e) => {
                  setHttps(e.target.value);
                  setVisible(PAGE_SIZE);
                }}
              >
                <option value="">All</option>
                <option value="yes">Required</option>
                <option value="no">HTTP ok</option>
              </select>
            </label>
            <label>
              CORS
              <select
                value={cors}
                onChange={(e) => {
                  setCors(e.target.value);
                  setVisible(PAGE_SIZE);
                }}
              >
                <option value="">All</option>
                <option value="Yes">Yes</option>
                <option value="No">No</option>
                <option value="Unknown">Unknown</option>
              </select>
            </label>
          </form>

          <div className="api-list">
            {!slice.length && <p className="empty">No APIs match these filters.</p>}
            {slice.map((api) => {
              const inStack = stack.some((item) => item.id === api.id);
              return (
                <article className="api-row" key={api.id}>
                  <div className="api-main">
                    <a href={api.url} target="_blank" rel="noopener noreferrer">
                      {api.name}
                    </a>
                    <p className="api-desc">{api.description}</p>
                    <div className="meta-row">
                      <span className="chip">{api.category}</span>
                      <span className="chip">Auth: {api.auth}</span>
                      <span className={`chip${api.https ? " on" : ""}`}>
                        HTTPS {api.https ? "Yes" : "No"}
                      </span>
                      <span className="chip">CORS {api.cors}</span>
                    </div>
                  </div>
                  <button
                    type="button"
                    className={`add-btn${inStack ? " in-stack" : ""}`}
                    onClick={() => toggleStack(api)}
                  >
                    {inStack ? "In stack" : "Add"}
                  </button>
                </article>
              );
            })}
          </div>
          {slice.length < filtered.length && (
            <button
              type="button"
              className="btn ghost load-more"
              onClick={() => setVisible((n) => n + PAGE_SIZE)}
            >
              Load more
            </button>
          )}
        </section>

        <section className="pro" id="pro" aria-labelledby="pro-title">
          <div className="pro-panel">
            <h2 id="pro-title">Stackpick Pro</h2>
            <p>
              Export stacks as JSON / CSV, share synced shortlist links, and run lightweight health
              checks. Free browse stays free — confirm your email after joining the waitlist to unlock
              Pro on this device while billing is prepared.
            </p>
            <ul className="pro-perks">
              <li>One-click stack export (JSON / CSV)</li>
              <li>Shareable shortlist links</li>
              <li>Endpoint health snapshots (catalog URLs only)</li>
              <li>Larger shortlist cap ({PRO_STACK_LIMIT})</li>
            </ul>
            <form className="waitlist" onSubmit={joinWaitlist}>
              <label>
                <span className="sr-only">Email</span>
                <input
                  type="email"
                  name="email"
                  value={waitlistEmail}
                  onChange={(e) => setWaitlistEmail(e.target.value)}
                  placeholder="you@company.com"
                  required
                />
              </label>
              <input
                className="hp"
                type="text"
                name="company"
                tabIndex={-1}
                autoComplete="off"
                aria-hidden="true"
              />
              <button type="submit" className="btn primary" disabled={waitlistBusy}>
                {isPro ? "Refresh Pro unlock" : "Join waitlist"}
              </button>
            </form>
            <p className="waitlist-note" role="status" aria-live="polite">
              {waitlistNote}
            </p>
            <p className="price-hint">
              Planned: $9 / month · cancel anytime · waitlist join is free and unlocks Pro tools now
            </p>
          </div>
        </section>
      </main>

      <aside
        className={`stack-panel${panelOpen ? " is-open" : ""}`}
        id="stack-panel"
        hidden={!panelOpen}
        aria-labelledby="stack-title"
      >
        <div className="stack-head">
          <h2 id="stack-title">Your stack</h2>
          <button type="button" className="icon-btn" onClick={() => setPanelOpen(false)} aria-label="Close stack">
            ×
          </button>
        </div>
        <ol id="stack-items">
          {!stack.length && <li className="empty">No APIs shortlisted yet.</li>}
          {stack.map((item) => (
            <li key={item.id}>
              <div>
                <strong>{item.name}</strong>
                <br />
                <small>{item.category}</small>
              </div>
              <button
                type="button"
                onClick={() => persistStack((prev) => prev.filter((x) => x.id !== item.id))}
              >
                Remove
              </button>
            </li>
          ))}
        </ol>
        <div className="stack-actions">
          <button type="button" className="btn ghost" onClick={() => persistStack([])}>
            Clear
          </button>
          <button type="button" className="btn ghost" onClick={() => exportStack("json")}>
            JSON
          </button>
          <button type="button" className="btn ghost" onClick={() => exportStack("csv")}>
            CSV
          </button>
          <button
            type="button"
            className="btn ghost"
            onClick={shareStack}
            disabled={busy === "share"}
          >
            Share
          </button>
          <button
            type="button"
            className="btn primary"
            onClick={runHealth}
            disabled={busy === "health"}
          >
            Health
          </button>
        </div>
        <p className="stack-hint">
          Free: save up to {FREE_STACK_LIMIT} locally. Pro unlocks export, share sync, health, and up
          to {PRO_STACK_LIMIT}.
        </p>
        {shareNote && (
          <p className="waitlist-note" role="status">
            {shareNote}
          </p>
        )}
        {healthNote && (
          <p className="waitlist-note" role="status">
            {healthNote}
          </p>
        )}
        {!!healthRows.length && (
          <ul className="health-list">
            {healthRows.map((row) => (
              <li key={row.id}>
                <strong>{row.name}</strong>{" "}
                <span className={row.ok ? "ok" : "bad"}>
                  {row.ok ? "OK" : "FAIL"} {row.status || row.error} · {row.ms}ms
                </span>
              </li>
            ))}
          </ul>
        )}
      </aside>
      <div
        className="stack-backdrop"
        hidden={!panelOpen}
        onClick={() => setPanelOpen(false)}
      />

      <footer className="site-footer">
        <p>
          Data sourced from the{" "}
          <a href="https://github.com/public-apis/public-apis" rel="noopener noreferrer" target="_blank">
            public-apis
          </a>{" "}
          community catalog. Partner links may earn referral credit.
          {sampleData && (
            <> Storage is running on sample in-memory data until Postgres is attached.</>
          )}
          {!mailConfigured && (
            <> Confirmation email needs the RESEND_API_KEY app secret for production unlocks.</>
          )}
        </p>
      </footer>
    </>
  );
}

function downloadBlob(filename, text, type) {
  const blob = new Blob([text], { type });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  a.click();
  URL.revokeObjectURL(url);
}
