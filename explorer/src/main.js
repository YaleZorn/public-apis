import './style.css';

const PAGE_SIZE = 40;
const FREE_STACK_LIMIT = 5;
const STORAGE_STACK = 'stackpick.stack.v1';
const STORAGE_WAITLIST = 'stackpick.waitlist.v1';

const state = {
  data: null,
  filtered: [],
  visible: PAGE_SIZE,
  stack: loadStack(),
};

const els = {
  q: document.getElementById('q'),
  category: document.getElementById('category'),
  auth: document.getElementById('auth'),
  https: document.getElementById('https'),
  cors: document.getElementById('cors'),
  apiList: document.getElementById('api-list'),
  resultMeta: document.getElementById('result-meta'),
  loadMore: document.getElementById('load-more'),
  partnerTrack: document.getElementById('partner-track'),
  stackCount: document.getElementById('stack-count'),
  stackPanel: document.getElementById('stack-panel'),
  stackBackdrop: document.getElementById('stack-backdrop'),
  stackItems: document.getElementById('stack-items'),
  waitlistForm: document.getElementById('waitlist-form'),
  waitlistNote: document.getElementById('waitlist-note'),
};

init().catch((err) => {
  els.resultMeta.textContent = 'Failed to load catalog.';
  console.error(err);
});

async function init() {
  const res = await fetch('/data/apis.json');
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  state.data = await res.json();
  fillCategories(state.data.categories);
  renderPartners(state.data.featuredPartners || []);
  applyFilters();
  bindEvents();
  renderStack();
  restoreWaitlistNote();
}

function bindEvents() {
  ['input', 'change'].forEach((evt) => {
    els.q.addEventListener(evt, () => {
      state.visible = PAGE_SIZE;
      applyFilters();
    });
  });
  [els.category, els.auth, els.https, els.cors].forEach((el) => {
    el.addEventListener('change', () => {
      state.visible = PAGE_SIZE;
      applyFilters();
    });
  });

  els.loadMore.addEventListener('click', () => {
    state.visible += PAGE_SIZE;
    renderList();
  });

  document.getElementById('open-stack').addEventListener('click', openStack);
  document.getElementById('close-stack').addEventListener('click', closeStack);
  els.stackBackdrop.addEventListener('click', closeStack);
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeStack();
  });
  document.getElementById('clear-stack').addEventListener('click', () => {
    state.stack = [];
    persistStack();
    renderStack();
    renderList();
  });
  document.getElementById('export-stack').addEventListener('click', () => {
    document.getElementById('pro').scrollIntoView({ behavior: 'smooth' });
    closeStack();
    els.waitlistNote.textContent = 'Export is a Pro feature — join the waitlist below.';
  });
  document.getElementById('hero-pro').addEventListener('click', () => {
    document.getElementById('pro').scrollIntoView({ behavior: 'smooth' });
  });

  els.waitlistForm.addEventListener('submit', (e) => {
    e.preventDefault();
    const email = new FormData(els.waitlistForm).get('email')?.toString().trim();
    if (!email) return;
    const existing = JSON.parse(localStorage.getItem(STORAGE_WAITLIST) || '[]');
    if (!existing.includes(email)) existing.push(email);
    localStorage.setItem(STORAGE_WAITLIST, JSON.stringify(existing));
    els.waitlistForm.reset();
    els.waitlistNote.textContent = `You're on the list as ${email}. We'll email when Pro opens.`;
  });
}

function fillCategories(categories) {
  for (const cat of categories) {
    const opt = document.createElement('option');
    opt.value = cat;
    opt.textContent = cat;
    els.category.appendChild(opt);
  }
}

function applyFilters() {
  const q = els.q.value.trim().toLowerCase();
  const category = els.category.value;
  const auth = els.auth.value;
  const https = els.https.value;
  const cors = els.cors.value;

  state.filtered = state.data.apis.filter((api) => {
    if (category && api.category !== category) return false;
    if (auth && api.auth !== auth) return false;
    if (https === 'yes' && !api.https) return false;
    if (https === 'no' && api.https) return false;
    if (cors && api.cors !== cors) return false;
    if (!q) return true;
    const hay = `${api.name} ${api.description} ${api.category}`.toLowerCase();
    return hay.includes(q);
  });

  renderList();
}

function renderList() {
  const slice = state.filtered.slice(0, state.visible);
  els.resultMeta.textContent = `${state.filtered.length.toLocaleString()} APIs match · showing ${slice.length}`;
  els.apiList.innerHTML = '';

  if (!slice.length) {
    els.apiList.innerHTML = '<p class="empty">No APIs match these filters.</p>';
    els.loadMore.hidden = true;
    return;
  }

  const frag = document.createDocumentFragment();
  for (const api of slice) {
    frag.appendChild(renderApiRow(api));
  }
  els.apiList.appendChild(frag);
  els.loadMore.hidden = slice.length >= state.filtered.length;
}

function renderApiRow(api) {
  const row = document.createElement('article');
  row.className = 'api-row';
  row.dataset.id = api.id;

  const inStack = state.stack.some((item) => item.id === api.id);
  row.innerHTML = `
    <div class="api-main">
      <a href="${escapeAttr(api.url)}" target="_blank" rel="noopener noreferrer">${escapeHtml(api.name)}</a>
      <p class="api-desc">${escapeHtml(api.description)}</p>
      <div class="meta-row">
        <span class="chip">${escapeHtml(api.category)}</span>
        <span class="chip">Auth: ${escapeHtml(api.auth)}</span>
        <span class="chip ${api.https ? 'on' : ''}">HTTPS ${api.https ? 'Yes' : 'No'}</span>
        <span class="chip">CORS ${escapeHtml(api.cors)}</span>
      </div>
    </div>
  `;

  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = `add-btn${inStack ? ' in-stack' : ''}`;
  btn.textContent = inStack ? 'In stack' : 'Add';
  btn.addEventListener('click', () => toggleStack(api));
  row.appendChild(btn);
  return row;
}

function renderPartners(partners) {
  els.partnerTrack.innerHTML = '';
  const list = partners.length
    ? partners
    : [
        {
          name: 'APILayer Suite',
          url: 'https://apilayer.com/?utm_source=Github&utm_medium=Referral&utm_campaign=Public-apis-repo',
          description: 'One account, one dashboard, production REST APIs.',
          label: 'Partner',
        },
      ];

  for (const p of list) {
    const a = document.createElement('a');
    a.className = 'partner-item';
    a.href = p.url;
    a.target = '_blank';
    a.rel = 'noopener noreferrer sponsored';
    a.innerHTML = `
      <span class="tag">${escapeHtml(p.label || 'Partner')}</span>
      <strong>${escapeHtml(p.name)}</strong>
      <span>${escapeHtml(p.description)}</span>
    `;
    els.partnerTrack.appendChild(a);
  }
}

function toggleStack(api) {
  const idx = state.stack.findIndex((item) => item.id === api.id);
  if (idx >= 0) {
    state.stack.splice(idx, 1);
  } else {
    if (state.stack.length >= FREE_STACK_LIMIT) {
      openStack();
      els.waitlistNote.textContent =
        'Free shortlist is limited to 5 APIs. Join Pro waitlist for larger synced stacks.';
      document.getElementById('pro').scrollIntoView({ behavior: 'smooth' });
      return;
    }
    state.stack.push({
      id: api.id,
      name: api.name,
      url: api.url,
      category: api.category,
    });
  }
  persistStack();
  renderStack();
  renderList();
}

function renderStack() {
  els.stackCount.textContent = String(state.stack.length);
  els.stackItems.innerHTML = '';
  if (!state.stack.length) {
    els.stackItems.innerHTML = '<li class="empty">No APIs shortlisted yet.</li>';
    return;
  }
  for (const item of state.stack) {
    const li = document.createElement('li');
    li.innerHTML = `<div><strong>${escapeHtml(item.name)}</strong><br /><small>${escapeHtml(item.category)}</small></div>`;
    const remove = document.createElement('button');
    remove.type = 'button';
    remove.textContent = 'Remove';
    remove.addEventListener('click', () => {
      state.stack = state.stack.filter((x) => x.id !== item.id);
      persistStack();
      renderStack();
      renderList();
    });
    li.appendChild(remove);
    els.stackItems.appendChild(li);
  }
}

function openStack() {
  els.stackBackdrop.hidden = false;
  els.stackPanel.hidden = false;
  // Restart enter animation each open (avoids stale fill-mode / FOUC frames).
  els.stackPanel.classList.remove('is-open');
  void els.stackPanel.offsetWidth;
  els.stackPanel.classList.add('is-open');
  renderStack();
}

function closeStack() {
  els.stackPanel.classList.remove('is-open');
  els.stackPanel.hidden = true;
  els.stackBackdrop.hidden = true;
}

function loadStack() {
  try {
    return JSON.parse(localStorage.getItem(STORAGE_STACK) || '[]');
  } catch {
    return [];
  }
}

function persistStack() {
  localStorage.setItem(STORAGE_STACK, JSON.stringify(state.stack));
}

function restoreWaitlistNote() {
  try {
    const list = JSON.parse(localStorage.getItem(STORAGE_WAITLIST) || '[]');
    if (list.length) {
      els.waitlistNote.textContent = `You're already on the waitlist (${list[list.length - 1]}).`;
    }
  } catch {
    /* ignore */
  }
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function escapeAttr(value) {
  return escapeHtml(value).replaceAll("'", '&#39;');
}
