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
  const [feedbackText, setFeedbackText] = useState("");
  const [feedbackEmail, setFeedbackEmail] = useState("");
  const [feedbackNote, setFeedbackNote] = useState("");
  const [feedbackBusy, setFeedbackBusy] = useState(false);
  const [adminToken, setAdminToken] = useState("");
  const [adminSummary, setAdminSummary] = useState(null);
  const [adminNote, setAdminNote] = useState("");
  const [user, setUser] = useState(null);
  const [authProviders, setAuthProviders] = useState({
    google: false,
    github: false,
    sampleLogin: false,
  });
  const [billing, setBilling] = useState({
    configured: false,
    public: false,
    subscribed: false,
    status: "inactive",
    priceUsd: 9,
    interval: "month",
  });
  const [billingBusy, setBillingBusy] = useState("");

  const isPro = Boolean(proEmail && proToken);
  const stackLimit = isPro ? PRO_STACK_LIMIT : FREE_STACK_LIMIT;

  async function refreshAuthUser() {
    try {
      const res = await fetch("/api/auth/me", { credentials: "include" });
      const payload = await res.json().catch(() => ({}));
      if (payload.billing) setBilling((prev) => ({ ...prev, ...payload.billing }));
      if (payload.user) {
        setUser(payload.user);
        if (payload.user.pro && payload.user.email && payload.user.proToken) {
          localStorage.setItem(STORAGE_PRO, payload.user.email);
          localStorage.setItem(STORAGE_PRO_TOKEN, payload.user.proToken);
          setProEmail(payload.user.email);
          setProToken(payload.user.proToken);
        } else {
          localStorage.removeItem(STORAGE_PRO);
          localStorage.removeItem(STORAGE_PRO_TOKEN);
          setProEmail("");
          setProToken("");
        }
      } else {
        setUser(null);
      }
    } catch {
      setUser(null);
    }
  }

  async function refreshBilling({ refresh = false } = {}) {
    try {
      const res = await fetch(`/api/billing/status${refresh ? "?refresh=1" : ""}`, {
        credentials: "include",
      });
      const payload = await res.json().catch(() => ({}));
      if (payload.billing) setBilling((prev) => ({ ...prev, ...payload.billing }));
      if (payload.billing?.subscribed) {
        await refreshAuthUser();
      } else if (payload.billing?.configured) {
        localStorage.removeItem(STORAGE_PRO);
        localStorage.removeItem(STORAGE_PRO_TOKEN);
        setProEmail("");
        setProToken("");
      }
    } catch {
      // ignore
    }
  }

  async function startCheckout() {
    setBillingBusy("checkout");
    setWaitlistNote("");
    try {
      const res = await fetch("/api/billing/checkout", {
        method: "POST",
        credentials: "include",
      });
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) {
        setWaitlistNote(
          payload.error === "sign_in_required"
            ? "Sign in first, then subscribe to Pro."
            : payload.error === "billing_not_configured" || payload.error === "billing_not_public"
              ? "Paid Pro checkout is not open yet. Browse Partner APIs in the meantime."
              : "Could not start checkout. Try again.",
        );
        return;
      }
      if (payload.url) {
        window.location.href = payload.url;
        return;
      }
      setWaitlistNote("Checkout session missing redirect URL.");
    } catch {
      setWaitlistNote("Network error starting checkout.");
    } finally {
      setBillingBusy("");
    }
  }

  async function openBillingPortal() {
    setBillingBusy("portal");
    setWaitlistNote("");
    try {
      const res = await fetch("/api/billing/portal", {
        method: "POST",
        credentials: "include",
      });
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) {
        setWaitlistNote(
          payload.error === "no_customer"
            ? "No Stripe customer yet — subscribe first."
            : "Could not open billing portal.",
        );
        return;
      }
      if (payload.url) {
        window.location.href = payload.url;
        return;
      }
    } catch {
      setWaitlistNote("Network error opening billing portal.");
    } finally {
      setBillingBusy("");
    }
  }

  async function signOut() {
    await fetch("/api/auth/logout", { method: "POST", credentials: "include" }).catch(() => {});
    setUser(null);
    localStorage.removeItem(STORAGE_PRO);
    localStorage.removeItem(STORAGE_PRO_TOKEN);
    setProEmail("");
    setProToken("");
    setWaitlistNote("Signed out.");
  }

  async function sampleSignIn() {
    const res = await fetch("/api/auth/sample", {
      method: "POST",
      credentials: "include",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "sample.user@example.com", name: "Sample User" }),
    });
    const payload = await res.json().catch(() => ({}));
    if (!res.ok) {
      setWaitlistNote("Sample sign-in unavailable.");
      return;
    }
    localStorage.setItem(STORAGE_PRO, payload.email);
    localStorage.setItem(STORAGE_PRO_TOKEN, payload.proToken);
    setProEmail(payload.email);
    setProToken(payload.proToken);
    await refreshAuthUser();
  }

  async function confirmWaitlistToken(confirmToken) {
    const res = await fetch("/api/waitlist/confirm", {
      method: "POST",
      credentials: "include",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token: confirmToken }),
    });
    const payload = await res.json().catch(() => ({}));
    if (!res.ok || !payload.email) {
      throw new Error(payload.error || "confirm_failed");
    }
    if (payload.pro && payload.token) {
      localStorage.setItem(STORAGE_PRO, payload.email);
      localStorage.setItem(STORAGE_PRO_TOKEN, payload.token);
      setProEmail(payload.email);
      setProToken(payload.token);
      setWaitlistNote(`Signed in as ${payload.email}. Pro tools unlocked.`);
    } else {
      localStorage.removeItem(STORAGE_PRO);
      localStorage.removeItem(STORAGE_PRO_TOKEN);
      setProEmail("");
      setProToken("");
      setWaitlistNote(
        `Signed in as ${payload.email}. Pro checkout is coming soon — try Partner APIs for production endpoints.`,
      );
    }
    await refreshAuthUser();
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
      setWaitlistNote("Please sign in again to refresh Pro access.");
    }

    const params = new URLSearchParams(window.location.search);
    const code = params.get("stack");
    const confirm = params.get("confirm");
    const authOk = params.get("auth");
    const authError = params.get("auth_error");
    if (authError) {
      setWaitlistNote(`Sign-in failed (${authError}). Check OAuth app settings and try again.`);
    } else if (authOk) {
      setWaitlistNote(`Signed in with ${authOk}.`);
    }
    if (authOk || authError) {
      const next = new URL(window.location.href);
      next.searchParams.delete("auth");
      next.searchParams.delete("auth_error");
      window.history.replaceState({}, "", next.pathname + next.search);
    }
    const billingParam = params.get("billing");
    if (billingParam === "success") {
      setWaitlistNote("Payment received — refreshing Pro access…");
      refreshBilling({ refresh: true }).then(() => {
        setWaitlistNote("Pro subscription active. Export, share, and health checks are unlocked.");
      });
      const next = new URL(window.location.href);
      next.searchParams.delete("billing");
      window.history.replaceState({}, "", next.pathname + next.search);
    } else if (billingParam === "cancel") {
      setWaitlistNote("Checkout canceled. You can subscribe anytime from your account.");
      const next = new URL(window.location.href);
      next.searchParams.delete("billing");
      window.history.replaceState({}, "", next.pathname + next.search);
    }
    refreshAuthUser();
    fetch("/api/status")
      .then((res) => res.json())
      .then((status) => {
        setSampleData(Boolean(status.sampleData));
        setMailConfigured(Boolean(status.mailConfigured));
        if (status.auth) setAuthProviders(status.auth);
        setBilling((prev) => ({
          ...prev,
          configured: Boolean(status.billingConfigured),
          public: Boolean(status.billingPublic),
        }));
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
          } catch (err) {
            setWaitlistNote(
              String(err?.message || "").includes("expired")
                ? "That sign-in link expired (30 minutes). Request a new email link."
                : "Sign-in link invalid or expired. Request a new email link.",
            );
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
          : "Free shortlist is limited to 5 APIs. Sign in to raise the cap and unlock export/health.",
      );
      document.getElementById("pro")?.scrollIntoView({ behavior: "smooth" });
    }
  }

  async function signInWithEmail(event) {
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
          source: "email-signin",
          company: form.get("company") || "",
        }),
      });
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) {
        if (payload.error === "rate_limited") {
          setWaitlistNote("Too many attempts. Try again in a few minutes.");
        } else if (payload.error === "mail_quota") {
          setWaitlistNote("Daily sign-in email quota reached. Try again tomorrow.");
        } else if (payload.error === "mail_failed") {
          const mailHints = {
            auth: "Resend rejected the API key. Check RESEND_API_KEY in app secrets.",
            from: "Sender address is not verified in Resend. Set RESEND_FROM to onboarding@resend.dev or a verified domain.",
            test_recipient:
              "Resend test mode only delivers to your Resend account email until you verify a domain.",
            provider: "Could not send sign-in email. Try again later.",
          };
          setWaitlistNote(mailHints[payload.reason] || mailHints.provider);
        } else {
          setWaitlistNote("Could not start email sign-in. Check the address and retry.");
        }
        return;
      }

      setWaitlistEmail("");
      if (payload.delivery === "cooldown") {
        setWaitlistNote("Sign-in email already sent recently. Check your inbox or wait an hour.");
        return;
      }
      if (payload.delivery === "email") {
        setWaitlistNote(`Check ${email} for a sign-in link. New and returning accounts use the same flow.`);
        return;
      }
      if (payload.delivery === "sample" && payload.sampleConfirmToken) {
        await confirmWaitlistToken(payload.sampleConfirmToken);
        return;
      }
      setWaitlistNote(
        "Email sign-in needs RESEND_API_KEY. Or use Google/GitHub once those secrets are added.",
      );
    } catch {
      setWaitlistNote("Network error starting email sign-in.");
    } finally {
      setWaitlistBusy(false);
    }
  }

  async function submitFeedback(event) {
    event.preventDefault();
    const message = feedbackText.trim();
    if (message.length < 8) {
      setFeedbackNote("Please write a bit more detail (8+ characters).");
      return;
    }
    setFeedbackBusy(true);
    setFeedbackNote("");
    try {
      const form = new FormData(event.currentTarget);
      const res = await fetch("/api/feedback", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          message,
          email: feedbackEmail.trim(),
          category: "general",
          company: form.get("company") || "",
        }),
      });
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) {
        setFeedbackNote(
          payload.error === "rate_limited"
            ? "Feedback rate limited. Try again later."
            : "Could not send feedback.",
        );
        return;
      }
      setFeedbackText("");
      setFeedbackNote("Thanks — feedback received.");
    } catch {
      setFeedbackNote("Network error sending feedback.");
    } finally {
      setFeedbackBusy(false);
    }
  }

  async function loadAdminSummary(event) {
    event?.preventDefault();
    setAdminNote("");
    setAdminSummary(null);
    const token = adminToken.trim();
    if (!token) {
      setAdminNote("Paste the ADMIN_TOKEN app secret to load ops data.");
      return;
    }
    try {
      const res = await fetch("/api/admin/summary", {
        headers: { "x-admin-token": token },
      });
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) {
        setAdminNote("Admin access denied.");
        return;
      }
      setAdminSummary(payload);
      setAdminNote("Admin summary loaded.");
    } catch {
      setAdminNote("Network error loading admin summary.");
    }
  }

  function exportStack(format) {
    if (!isPro) {
      setWaitlistNote(billing.public ? "Export unlocks with a Pro subscription." : "Export unlocks after you sign in.");
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
    if (!isPro) {
      setWaitlistNote(billing.public ? "Share links unlock with a Pro subscription." : "Share links unlock after you sign in.");
      document.getElementById("pro")?.scrollIntoView({ behavior: "smooth" });
      return;
    }
    if (!stack.length) {
      setShareNote("Add APIs before sharing.");
      return;
    }
    setBusy("share");
    setShareNote("");
    try {
      const res = await fetch("/api/stacks", {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-stackpick-token": proToken,
        },
        body: JSON.stringify({ ids: stack.map((item) => item.id), token: proToken }),
      });
      const payload = await res.json().catch(() => ({}));
      if (!res.ok) {
        setShareNote(
          payload.error === "rate_limited" || payload.error === "creator_cap"
            ? "Too many shares from this network. Try again later."
            : payload.error === "capacity"
              ? "Share capacity is full. Try again later."
              : payload.error === "pro_required"
                ? "Session expired. Sign in again to refresh access."
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
      setWaitlistNote(billing.public ? "Health checks unlock with a Pro subscription." : "Health checks unlock after you sign in.");
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
              ? "Session expired. Sign in again to refresh access."
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
        <nav className="topnav" aria-label="Primary">
          <a href="#catalog">Catalog</a>
          <a href="#partners">Partners</a>
          <a href="#feedback">Feedback</a>
          {user ? (
            <a className="auth-chip" href="#pro" title={user.email || ""}>
              {user.name || user.email}
            </a>
          ) : (
            <a className="stack-btn" href="#pro">
              Sign in
            </a>
          )}
          <button
            type="button"
            className={`stack-btn${stack.length ? " has-items" : ""}`}
            onClick={() => setPanelOpen(true)}
            aria-controls="stack-panel"
            aria-expanded={panelOpen}
          >
            Stack <span>{stack.length}</span>
          </button>
        </nav>
      </header>

      <main id="top">
        <section className="hero">
          <h1>Stackpick</h1>
          <p className="lede">
            Search 1,600+ public APIs, shortlist a stack, and jump to production-ready Partner
            options when free endpoints are not enough.
          </p>
          <div className="cta-row">
            <a className="btn primary" href="#catalog">
              Browse catalog
            </a>
            <a className="btn ghost" href="#partners">
              See partners
            </a>
          </div>
          {user && (
            <p className="hero-status" role="status">
              Signed in as {user.email || user.name}. Open your stack anytime from the top bar.
            </p>
          )}
        </section>

        <section className="catalog" id="catalog" aria-labelledby="catalog-title">
          <div className="section-head">
            <h2 id="catalog-title">Catalog</h2>
            <p>
              {filtered.length.toLocaleString()} matching APIs · showing {slice.length}
              {isPro ? " · Pro unlocked" : " · browsing free"}
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
                placeholder="Try weather, payments, or anime…"
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
            {!slice.length && (
              <div className="empty-state">
                <p className="empty-title">Nothing matches that filter</p>
                <p className="empty">Try a broader search, or clear a filter and look again.</p>
                <button
                  type="button"
                  className="btn ghost"
                  onClick={() => {
                    setQ("");
                    setCategory("");
                    setAuth("");
                    setHttps("");
                    setCors("");
                    setVisible(PAGE_SIZE);
                  }}
                >
                  Clear filters
                </button>
              </div>
            )}
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
                    aria-pressed={inStack}
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
              Show more APIs
            </button>
          )}
        </section>

        <section className="partners" id="partners" aria-labelledby="partners-title">
          <div className="section-head">
            <h2 id="partners-title">Partner APIs</h2>
            <p>
              Production-ready options with clear Partner labels. Referrals keep Stackpick free to
              browse — no card required.
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

        <section className="pro" id="pro" aria-labelledby="pro-title">
          <div className="pro-panel">
            {user || isPro ? (
              <>
                <h2 id="pro-title">{isPro ? "Pro tools unlocked" : "Your account"}</h2>
                <p>
                  You are signed in
                  {user?.email || proEmail ? ` as ${(user && user.email) || proEmail}` : ""}.
                  {isPro
                    ? " Export, share, and health checks are unlocked on this device."
                    : " Paid Pro checkout is coming soon — until then, explore Partner APIs for production needs."}
                </p>
                <ul className="pro-perks">
                  <li>Shortlist up to {isPro ? PRO_STACK_LIMIT : FREE_STACK_LIMIT} APIs{isPro ? "" : ` (Pro soon: ${PRO_STACK_LIMIT})`}</li>
                  <li>Export JSON / CSV from the stack drawer</li>
                  <li>Share a link and run catalog health checks</li>
                </ul>
                <div className="auth-row">
                  <button
                    type="button"
                    className="btn primary"
                    onClick={() => setPanelOpen(true)}
                  >
                    Open your stack
                  </button>
                  <a className="btn ghost" href="#partners">
                    Browse partners
                  </a>
                  {billing.public && !isPro && (
                    <button
                      type="button"
                      className="btn ghost"
                      onClick={startCheckout}
                      disabled={billingBusy === "checkout"}
                    >
                      {billingBusy === "checkout" ? "Redirecting…" : `Subscribe · $${billing.priceUsd}/mo`}
                    </button>
                  )}
                  {billing.public && isPro && (
                    <button
                      type="button"
                      className="btn ghost"
                      onClick={openBillingPortal}
                      disabled={billingBusy === "portal"}
                    >
                      {billingBusy === "portal" ? "Opening…" : "Manage billing"}
                    </button>
                  )}
                  <button type="button" className="btn ghost" onClick={signOut}>
                    Sign out
                  </button>
                </div>
                {!billing.public && (
                  <p className="price-hint">
                    Paid Pro (planned ${billing.priceUsd}/{billing.interval}) is not open for checkout yet.
                    Partner referrals help keep the catalog free.
                  </p>
                )}
                {billing.public && billing.currentPeriodEnd && isPro && (
                  <p className="price-hint">
                    Renews or ends{" "}
                    {new Date(billing.currentPeriodEnd).toLocaleDateString(undefined, {
                      year: "numeric",
                      month: "short",
                      day: "numeric",
                    })}
                    {billing.cancelAtPeriodEnd ? " · cancellation scheduled" : ""}
                  </p>
                )}
              </>
            ) : (
              <>
                <h2 id="pro-title">
                  {billing.public ? "Sign in, then subscribe" : "Sign in"}
                </h2>
                <p>
                  {billing.public
                    ? `Create an account with Google, GitHub, or email, then subscribe for $${billing.priceUsd}/month.`
                    : "Google, GitHub, or a one-time email link. Signing in unlocks export, share, and health checks for now. Need production APIs? Use Partner links — no signup wall."}
                </p>
                <ul className="pro-perks">
                  <li>Export stacks as JSON or CSV</li>
                  <li>Share a shortlist link with teammates</li>
                  <li>Check whether catalog endpoints respond</li>
                  <li>Raise the shortlist cap to {PRO_STACK_LIMIT}</li>
                </ul>
                <div className="auth-row">
                  {authProviders.google ? (
                    <a className="btn primary" href="/api/auth/google">
                      Continue with Google
                    </a>
                  ) : null}
                  {authProviders.github ? (
                    <a className={`btn ${authProviders.google ? "ghost" : "primary"}`} href="/api/auth/github">
                      Continue with GitHub
                    </a>
                  ) : null}
                  {authProviders.sampleLogin && (
                    <button type="button" className="btn ghost" onClick={sampleSignIn}>
                      Try a sample account
                    </button>
                  )}
                  {!authProviders.google && !authProviders.github && !authProviders.sampleLogin && (
                    <p className="price-hint">
                      Social sign-in needs Google/GitHub app secrets. Email link below still works when
                      mail is configured.
                    </p>
                  )}
                </div>
                <div className="auth-divider">
                  <span>or use email</span>
                </div>
                <form className="waitlist" onSubmit={signInWithEmail}>
                  <label>
                    <span className="sr-only">Email</span>
                    <input
                      type="email"
                      name="email"
                      value={waitlistEmail}
                      onChange={(e) => setWaitlistEmail(e.target.value)}
                      placeholder="you@company.com"
                      required
                      autoComplete="email"
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
                    {waitlistBusy ? "Sending…" : "Send sign-in link"}
                  </button>
                </form>
                <p className="price-hint">
                  We email a one-time link — no password to remember.
                  {billing.public
                    ? ` After sign-in, subscribe for $${billing.priceUsd}/month.`
                    : " Signing in unlocks Pro for now. Paid checkout is coming soon."}
                </p>
              </>
            )}
            {waitlistNote && (
              <p className="status-note" role="status" aria-live="polite">
                {waitlistNote}
              </p>
            )}
          </div>
        </section>

        <section className="feedback-section" id="feedback" aria-labelledby="feedback-title">
          <div className="feedback-panel">
            <h2 id="feedback-title">Send a note</h2>
            <p>Bugs, missing APIs, or Partner ideas — short notes help most.</p>
            <form className="waitlist feedback-form" onSubmit={submitFeedback}>
              <label className="feedback-box">
                <span className="sr-only">Message</span>
                <textarea
                  value={feedbackText}
                  onChange={(e) => setFeedbackText(e.target.value)}
                  placeholder="What should we improve?"
                  rows={4}
                  required
                  minLength={8}
                  maxLength={2000}
                />
              </label>
              <label>
                <span className="sr-only">Email (optional)</span>
                <input
                  type="email"
                  value={feedbackEmail}
                  onChange={(e) => setFeedbackEmail(e.target.value)}
                  placeholder="Email if you want a reply (optional)"
                  autoComplete="email"
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
              <button type="submit" className="btn ghost" disabled={feedbackBusy}>
                {feedbackBusy ? "Sending…" : "Send feedback"}
              </button>
            </form>
            {feedbackNote && (
              <p className="status-note" role="status" aria-live="polite">
                {feedbackNote}
              </p>
            )}
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
          {!stack.length && (
            <li className="empty-state compact">
              <p className="empty-title">Your stack is empty</p>
              <p className="empty">
                Add APIs from the catalog — or open{" "}
                <a href="#partners">Partner APIs</a> when you need production-grade endpoints.
              </p>
            </li>
          )}
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
          Free shortlist: {FREE_STACK_LIMIT} APIs.
          {billing.public
            ? ` Subscribe ($${billing.priceUsd}/mo) for export, share, health, and up to ${PRO_STACK_LIMIT}.`
            : ` Sign in for export, share, health, and up to ${PRO_STACK_LIMIT}. Paid Pro coming soon — see Partners.`}
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
          Data from the{" "}
          <a href="https://github.com/public-apis/public-apis" rel="noopener noreferrer" target="_blank">
            public-apis
          </a>{" "}
          community catalog. Partner links are labeled referrals and may earn credit — the main way
          Stackpick stays free while paid Pro checkout is prepared.
          {sampleData && <> Running on sample in-memory storage until Postgres is attached.</>}
          {!mailConfigured && !authProviders.google && !authProviders.github && (
            <> Email sign-in needs RESEND_API_KEY when you leave sample mode.</>
          )}
        </p>
        <details className="ops-details">
          <summary>Owner ops</summary>
          <p className="price-hint">
            Requires a long ADMIN_TOKEN app secret (24+ chars). Leave blank if you are not the owner.
          </p>
          <form className="waitlist" onSubmit={loadAdminSummary}>
            <label>
              <span className="sr-only">Admin token</span>
              <input
                type="password"
                value={adminToken}
                onChange={(e) => setAdminToken(e.target.value)}
                placeholder="ADMIN_TOKEN"
                autoComplete="off"
              />
            </label>
            <button type="submit" className="btn ghost">
              Load summary
            </button>
          </form>
          {adminNote && (
            <p className="status-note" role="status">
              {adminNote}
            </p>
          )}
          {adminSummary?.stats && (
            <ul className="ops-stats">
              <li>Accounts: {adminSummary.stats.accounts ?? adminSummary.stats.waitlist}</li>
              <li>Confirmed: {adminSummary.stats.confirmed}</li>
              <li>Subscribers: {adminSummary.stats.subscribers ?? 0}</li>
              <li>Active shares: {adminSummary.stats.activeStacks}</li>
              <li>New feedback: {adminSummary.stats.newFeedback}</li>
              <li>Mail today: {adminSummary.stats.mailSentToday}</li>
            </ul>
          )}
          {!!adminSummary?.feedback?.length && (
            <ul className="health-list">
              {adminSummary.feedback.slice(0, 8).map((item) => (
                <li key={item.id}>
                  <strong>{item.category}</strong>{" "}
                  <span>
                    {item.status} · {(item.message || "").slice(0, 120)}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </details>
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
