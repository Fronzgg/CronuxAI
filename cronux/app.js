const API = 'http://localhost:3000/api';
const LABEL = { 'cronux':'CronuxAI', 'cronux-coder':'CronuxCoder', 'cronux-pro':'CronuxPro' };
const SUGGESTIONS = [
  ['Расскажи подробнее', 'Приведи пример', 'Как это работает?'],
  ['Объясни проще', 'Что дальше?', 'Дай альтернативу'],
  ['Покажи код', 'Сравни варианты', 'Плюсы и минусы?'],
];

// Лимиты: free = 3 запроса/день, pro = 100/день
const LIMITS = { free: 3, pro: 100 };

let S = {
  user: null, chats: [], activeId: null,
  model: 'cronux', search: false, think: false,
  pendingImg: null, loading: false,
};

const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const cap = s => s.charAt(0).toUpperCase() + s.slice(1);
const today = () => new Date().toISOString().split('T')[0];

// ── AUTH ──────────────────────────────────────────────
function getUsers() {
  const u = JSON.parse(localStorage.getItem('cx_u') || '{}');
  if (!u['fronz']) {
    u['fronz'] = { username:'Fronz', password:'fronz123', unlimited:true, plan:'pro' };
    localStorage.setItem('cx_u', JSON.stringify(u));
  }
  return u;
}

function login() {
  const n = $('loginUser').value.trim().toLowerCase(), p = $('loginPass').value;
  const u = getUsers()[n];
  if (!u || u.password !== p) return authErr('Неверные данные');
  startSession(u);
}

function register() {
  const n = $('regUser').value.trim().toLowerCase();
  const e = $('regEmail').value.trim();
  const p = $('regPass').value;
  if (!n||!e||!p) return authErr('Заполните все поля');
  const users = getUsers();
  if (users[n]) return authErr('Пользователь уже существует');
  users[n] = { username: cap(n), password: p, unlimited: false, plan: 'free' };
  localStorage.setItem('cx_u', JSON.stringify(users));
  startSession(users[n]);
}

function startSession(u) {
  S.user = u;
  localStorage.setItem('cx_s', JSON.stringify(u));
  $('authModal').classList.add('hidden');
  initApp();
}

function logout() {
  if (!confirm('Выйти из аккаунта?')) return;
  localStorage.removeItem('cx_s');
  location.reload();
}

function authErr(m) {
  $('authError').textContent = m;
  setTimeout(() => $('authError').textContent = '', 3000);
}

function switchTab(t) {
  $('loginForm').style.display = t==='login' ? '' : 'none';
  $('registerForm').style.display = t==='register' ? '' : 'none';
  document.querySelectorAll('.auth-tab').forEach((b,i) =>
    b.classList.toggle('active', i===(t==='login'?0:1))
  );
}

// ── PLAN & CREDITS ────────────────────────────────────
function isPro() { return S.user.unlimited || S.user.plan === 'pro'; }

function getMsgsToday() {
  const k = `cx_msgs_${S.user.username.toLowerCase()}_${today()}`;
  return parseInt(localStorage.getItem(k) || '0');
}

function incMsgsToday() {
  const k = `cx_msgs_${S.user.username.toLowerCase()}_${today()}`;
  localStorage.setItem(k, (getMsgsToday() + 1).toString());
}

function canSendMsg() {
  if (S.user.unlimited) return true;
  const limit = isPro() ? LIMITS.pro : LIMITS.free;
  return getMsgsToday() < limit;
}

function getRemainingMsgs() {
  if (S.user.unlimited) return Infinity;
  const limit = isPro() ? LIMITS.pro : LIMITS.free;
  return Math.max(0, limit - getMsgsToday());
}

function updateCredHint() {
  const el = $('credHint');
  if (!el) return;
  if (S.user.unlimited) { el.textContent = ''; return; }
  const rem = getRemainingMsgs();
  const limit = isPro() ? LIMITS.pro : LIMITS.free;
  el.textContent = `${rem}/${limit} запросов`;
  el.style.color = rem <= 1 ? '#f87171' : 'var(--t3)';
}

// Активировать Pro (заглушка — в реальности после оплаты)
function activatePro() {
  const users = getUsers();
  const key = S.user.username.toLowerCase();
  users[key].plan = 'pro';
  users[key].unlimited = false;
  localStorage.setItem('cx_u', JSON.stringify(users));
  S.user = users[key];
  localStorage.setItem('cx_s', JSON.stringify(S.user));
  closeProModal();
  closeAccountPopup();
  showToast('✦ Pro активирован! 100 запросов в день');
  updateCredHint();
}

// ── CHATS ─────────────────────────────────────────────
const chatsKey = () => `cx_chats_${S.user.username.toLowerCase()}`;
function loadChats() { S.chats = JSON.parse(localStorage.getItem(chatsKey()) || '[]'); }
function saveChats() { localStorage.setItem(chatsKey(), JSON.stringify(S.chats)); }

function newChat() {
  const id = Date.now().toString();
  S.chats.unshift({ id, title:'Новый чат', messages:[], model: S.model });
  S.activeId = id;
  saveChats();
  renderSidebar();
  renderMessages();
  closeSidebar();
}

function switchChat(id) {
  if (S.activeId === id) return;
  S.activeId = id;
  const c = activeChat();
  if (c) {
    S.model = c.model || 'cronux';
    syncTabs();
    updateTopbarModel();
  }
  renderSidebar();
  renderMessages();   // ← полный перерендер сообщений
  closeSidebar();
}

function deleteChat(id, e) {
  e.stopPropagation();
  S.chats = S.chats.filter(c => c.id !== id);
  if (S.activeId === id) {
    S.activeId = S.chats[0]?.id || null;
    if (S.activeId) {
      S.model = activeChat()?.model || 'cronux';
      syncTabs();
    }
  }
  saveChats();
  renderSidebar();
  renderMessages();
}

const activeChat = () => S.chats.find(c => c.id === S.activeId) || null;

// ── SIDEBAR ───────────────────────────────────────────
function renderSidebar() {
  const list = $('chatList');
  if (!S.chats.length) {
    list.innerHTML = '<div style="padding:12px 10px;font-size:12px;color:var(--t3)">Нет чатов</div>';
    return;
  }
  const now = Date.now();
  const g = { today:[], week:[], older:[] };
  S.chats.forEach(c => {
    const age = now - (parseInt(c.id)||0);
    if (age < 86400000) g.today.push(c);
    else if (age < 604800000) g.week.push(c);
    else g.older.push(c);
  });
  let html = '';
  const rg = (lbl, items) => {
    if (!items.length) return;
    html += `<div class="chat-group-lbl">${lbl}</div>`;
    items.forEach(c => {
      html += `<div class="chat-row ${c.id===S.activeId?'active':''}" onclick="switchChat('${c.id}')">
        <span class="chat-row-title">${esc(c.title)}</span>
        <button class="chat-row-del" onclick="deleteChat('${c.id}',event)">✕</button>
      </div>`;
    });
  };
  rg('Сегодня', g.today); rg('7 дней', g.week); rg('Ранее', g.older);
  list.innerHTML = html;
}

// ── MESSAGES ──────────────────────────────────────────
function renderMessages() {
  const chat = activeChat();
  const cont = $('messages');
  const wel = $('welcome');
  const tb = $('topbar');

  // Всегда очищаем контейнер
  cont.innerHTML = '';

  if (!chat || !chat.messages.length) {
    cont.appendChild(wel);
    wel.style.display = '';
    tb.classList.add('hidden');
    return;
  }

  wel.style.display = 'none';
  tb.classList.remove('hidden');
  updateTopbarModel();

  chat.messages.forEach((m, i) => {
    cont.appendChild(buildMsg(m));
    if (m.role === 'assistant' && i === chat.messages.length - 1) {
      cont.appendChild(buildChips());
    }
  });
  cont.scrollTop = cont.scrollHeight;
}

function updateTopbarModel() {
  const el = $('topbarModel');
  if (el) el.textContent = LABEL[S.model] || 'CronuxAI';
}

function buildMsg(m) {
  const div = document.createElement('div');
  div.className = `message ${m.role}`;
  const isUser = m.role === 'user';
  const avaHtml = isUser
    ? `<div class="msg-ava">${S.user.username[0].toUpperCase()}</div>`
    : `<div class="msg-ava"><img src="logo.png" alt="AI"/></div>`;
  let body = '';
  if (m.imgUrl) body += `<img src="${m.imgUrl}" class="msg-image" alt="img"/>`;
  if (m.searchUsed) body += `<div class="search-badge">🔍 Web search</div>`;
  body += `<div class="msg-text">${fmt(m.content)}</div>`;
  if (!isUser) {
    body += `<div class="msg-actions">
      <button class="msg-act-btn" onclick="copyMsg(this)" title="Копировать">📋</button>
      <button class="msg-act-btn" title="Нравится">👍</button>
      <button class="msg-act-btn" title="Не нравится">👎</button>
      <button class="msg-act-btn" onclick="regenMsg()" title="Повторить">🔄</button>
    </div>`;
  }
  div.innerHTML = `${avaHtml}<div class="msg-body">
    <div class="msg-name">${isUser ? esc(S.user.username) : LABEL[m.model||S.model]||'CronuxAI'}</div>
    ${body}</div>`;
  return div;
}

function buildChips() {
  const set = SUGGESTIONS[Math.floor(Math.random() * SUGGESTIONS.length)];
  const div = document.createElement('div');
  div.className = 'suggestions';
  div.innerHTML = set.map(s =>
    `<button class="sug-chip" onclick="sendQuick('${esc(s)}')">${esc(s)}</button>`
  ).join('');
  return div;
}

function addTyping() {
  const div = document.createElement('div');
  div.className = 'message assistant'; div.id = 'typing';
  div.innerHTML = `<div class="msg-ava"><img src="logo.png" alt="AI"/></div>
    <div class="msg-body"><div class="msg-name">${LABEL[S.model]||'CronuxAI'}</div>
    <div class="msg-text"><div class="typing-dots">
      <div class="typing-dot"></div><div class="typing-dot"></div><div class="typing-dot"></div>
    </div></div></div>`;
  $('messages').appendChild(div);
  $('messages').scrollTop = $('messages').scrollHeight;
}
function removeTyping() { const el = $('typing'); if (el) el.remove(); }

// ── SEND ──────────────────────────────────────────────
async function sendMessage() {
  if (S.loading) return;
  const input = $('msgInput');
  const text = input.value.trim();
  const img = S.pendingImg;
  if (!text && !img) return;

  // Проверка лимита
  if (!canSendMsg()) {
    if (isPro()) {
      showToast('Дневной лимит Pro исчерпан (100 запросов). Обновится завтра.');
    } else {
      openProModal();
    }
    return;
  }

  if (!S.activeId) newChat();
  incMsgsToday();
  updateCredHint();

  const chat = activeChat();
  if (!chat.messages.length) {
    chat.title = text.slice(0, 45) || 'Изображение';
    renderSidebar();
  }

  const userMsg = { role:'user', content:text, imgUrl:img?.dataUrl||null, model:S.model, ts:Date.now() };
  chat.messages.push(userMsg);
  saveChats();

  input.value = ''; autoResize(input); clearImg();
  $('welcome').style.display = 'none';
  $('topbar').classList.remove('hidden');
  updateTopbarModel();
  document.querySelectorAll('.suggestions').forEach(el => el.remove());

  const cont = $('messages');
  cont.appendChild(buildMsg(userMsg));
  cont.scrollTop = cont.scrollHeight;

  S.loading = true; $('sendBtn').disabled = true; addTyping();

  try {
    let resp;
    if (img) {
      const ocrText = await doOCR(img.file);
      const combined = text ? `${text}\n\n[OCR]:\n${ocrText}` : ocrText;
      resp = await apiChat(combined, chat.messages.slice(0,-1));
    } else if (S.search) {
      trackSearch();
      resp = await apiWithSearch(text, chat.messages.slice(0,-1));
    } else {
      resp = await apiChat(text, chat.messages.slice(0,-1));
    }
    removeTyping();
    const aiMsg = { role:'assistant', content:resp.text, model:S.model, searchUsed:resp.searchUsed||false, ts:Date.now() };
    chat.messages.push(aiMsg); saveChats();
    cont.appendChild(buildMsg(aiMsg));
    cont.appendChild(buildChips());
    cont.scrollTop = cont.scrollHeight;
  } catch(e) {
    removeTyping();
    const errMsg = { role:'assistant', content:`Ошибка: ${e.message}`, model:S.model, ts:Date.now() };
    chat.messages.push(errMsg); saveChats();
    cont.appendChild(buildMsg(errMsg));
    cont.scrollTop = cont.scrollHeight;
  } finally {
    S.loading = false; $('sendBtn').disabled = false;
  }
}

function sendQuick(text) { $('msgInput').value = text; sendMessage(); }

async function regenMsg() {
  const chat = activeChat(); if (!chat || chat.messages.length < 2) return;
  document.querySelectorAll('.suggestions').forEach(el => el.remove());
  const msgs = $('messages').querySelectorAll('.message.assistant');
  const last = msgs[msgs.length-1]; if (last) last.remove();
  const lastIdx = chat.messages.map(m=>m.role).lastIndexOf('assistant');
  if (lastIdx > -1) chat.messages.splice(lastIdx, 1);
  const lastUser = [...chat.messages].reverse().find(m=>m.role==='user');
  if (!lastUser) return;
  S.loading = true; $('sendBtn').disabled = true; addTyping();
  try {
    const resp = await apiChat(lastUser.content, chat.messages.filter(m=>m!==lastUser));
    removeTyping();
    const aiMsg = { role:'assistant', content:resp.text, model:S.model, ts:Date.now() };
    chat.messages.push(aiMsg); saveChats();
    $('messages').appendChild(buildMsg(aiMsg));
    $('messages').appendChild(buildChips());
    $('messages').scrollTop = $('messages').scrollHeight;
  } catch(_) { removeTyping(); }
  finally { S.loading = false; $('sendBtn').disabled = false; }
}

function copyMsg(btn) {
  const text = btn.closest('.msg-body').querySelector('.msg-text')?.innerText || '';
  navigator.clipboard.writeText(text).then(() => {
    btn.textContent = '✅'; setTimeout(() => btn.textContent = '📋', 1500);
  });
}

// ── API ───────────────────────────────────────────────
function getMemoryContext() {
  const mem = getMemory();
  return mem.length ? `\n\n[Память о пользователе]:\n${mem.map(m=>'- '+m).join('\n')}` : '';
}

async function apiChat(text, history) {
  const res = await fetch(`${API}/chat`, {
    method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({
      message: text + getMemoryContext(),
      model: S.model,
      history: history.map(m=>({role:m.role, content:m.content}))
    }),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const d = await res.json();
  return { text: d.response, searchUsed: false };
}

async function apiWithSearch(text, history) {
  const sr = await fetch(`${API}/search`, {
    method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({ query: text }),
  });
  const sd = sr.ok ? await sr.json() : { results:'' };
  const aug = sd.results
    ? `Вопрос: ${text}\n\nРезультаты поиска:\n${sd.results}\n\nОтветь на основе этих данных.`
    : text;
  const r = await apiChat(aug, history);
  return { ...r, searchUsed: true };
}

async function doOCR(file) {
  try {
    const fd = new FormData(); fd.append('image', file);
    const r = await fetch(`${API}/ocr`, { method:'POST', body:fd });
    if (r.ok) { const d = await r.json(); if (d.text) return d.text; }
  } catch(_) {}
  try {
    const r = await Tesseract.recognize(file,'rus+eng',{logger:()=>{}});
    return r.data.text || '(текст не распознан)';
  } catch(_) { return '(OCR недоступен)'; }
}

// ── MEMORY ────────────────────────────────────────────
function memKey() { return `cx_mem_${S.user.username.toLowerCase()}`; }
function getMemory() { return JSON.parse(localStorage.getItem(memKey()) || '[]'); }
function saveMemoryData(arr) { localStorage.setItem(memKey(), JSON.stringify(arr)); }

function renderMemoryList() {
  const mem = getMemory();
  const container = $('apMemory');
  if (!mem.length) {
    container.innerHTML = '<div class="ap-memory-empty">Память пуста</div>';
    return;
  }
  container.innerHTML = mem.map((item, i) => `
    <div class="ap-mem-item">
      <span class="ap-mem-item-text">${esc(item)}</span>
      <button class="ap-mem-del" onclick="deleteMemory(${i})">✕</button>
    </div>`).join('');
}

function addMemory() { $('memoryModal').classList.remove('hidden'); $('memInput').value = ''; setTimeout(()=>$('memInput').focus(),100); }
function saveMemory() {
  const text = $('memInput').value.trim(); if (!text) return;
  const mem = getMemory(); mem.push(text); saveMemoryData(mem);
  closeMemoryModal(); renderMemoryList();
}
function deleteMemory(i) { const mem = getMemory(); mem.splice(i,1); saveMemoryData(mem); renderMemoryList(); }
function closeMemoryModal() { $('memoryModal').classList.add('hidden'); }

// ── ACCOUNT POPUP ─────────────────────────────────────
function openAccountPopup() {
  $('accountPopup').classList.remove('hidden');
  $('accountPopupOverlay').classList.remove('hidden');

  $('apAva').textContent = S.user.username[0].toUpperCase();
  $('apName').textContent = S.user.username;
  $('apPlan').textContent = isPro() ? (S.user.unlimited ? 'Pro · Безлимит ∞' : 'Pro · 100/день') : 'Free · 3/день';

  const msgsToday = getMsgsToday();
  const limit = S.user.unlimited ? '∞' : (isPro() ? LIMITS.pro : LIMITS.free);
  const limitNum = S.user.unlimited ? 999 : (isPro() ? LIMITS.pro : LIMITS.free);
  $('apMsgsToday').textContent = S.user.unlimited ? msgsToday : `${msgsToday}/${limit}`;
  $('apMsgsBar').style.width = `${Math.min(msgsToday/limitNum*100,100)}%`;

  $('apCredits').textContent = S.user.unlimited ? '∞' : `${getRemainingMsgs()}`;
  $('apCredBar').style.width = S.user.unlimited ? '100%' : `${getRemainingMsgs()/limitNum*100}%`;

  const srchKey = `cx_srch_${S.user.username.toLowerCase()}_${today()}`;
  const searches = parseInt(localStorage.getItem(srchKey)||'0');
  $('apSearches').textContent = searches;
  $('apSearchBar').style.width = `${Math.min(searches/20*100,100)}%`;

  $('apChatsTotal').textContent = S.chats.length;
  $('apChatsBar').style.width = `${Math.min(S.chats.length/20*100,100)}%`;

  // Показать/скрыть кнопку Pro
  $('apProBtn').style.display = isPro() ? 'none' : '';

  renderMemoryList();
}

function closeAccountPopup() {
  $('accountPopup').classList.add('hidden');
  $('accountPopupOverlay').classList.add('hidden');
}

// ── PRO MODAL ─────────────────────────────────────────
function openProModal() {
  closeAccountPopup();
  $('proModal').classList.remove('hidden');
}
function closeProModal() { $('proModal').classList.add('hidden'); }

// ── TRACKING ──────────────────────────────────────────
function trackSearch() {
  const k = `cx_srch_${S.user.username.toLowerCase()}_${today()}`;
  localStorage.setItem(k, (parseInt(localStorage.getItem(k)||'0')+1).toString());
}

// ── TOAST ─────────────────────────────────────────────
function showToast(msg) {
  let t = $('toast');
  if (!t) {
    t = document.createElement('div'); t.id = 'toast';
    t.style.cssText = 'position:fixed;bottom:90px;left:50%;transform:translateX(-50%);background:#1e1e2a;border:1px solid var(--bdr);color:var(--t1);padding:10px 20px;border-radius:10px;font-size:13px;z-index:999;animation:msgIn .2s ease;white-space:nowrap';
    document.body.appendChild(t);
  }
  t.textContent = msg; t.style.display = 'block';
  setTimeout(() => { t.style.display = 'none'; }, 3000);
}

// ── UI ────────────────────────────────────────────────
function toggleSearch() { S.search = !S.search; $('pillSearch').classList.toggle('on', S.search); }
function toggleThink()  { S.think  = !S.think;  $('pillThink').classList.toggle('on', S.think); }

function setTab(model, btn) {
  S.model = model;
  document.querySelectorAll('.model-tab').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  const c = activeChat(); if (c) { c.model = model; saveChats(); }
  updateTopbarModel();
}

function syncTabs() {
  const idx = {'cronux':0,'cronux-coder':1,'cronux-pro':2};
  document.querySelectorAll('.model-tab').forEach((b,i) =>
    b.classList.toggle('active', i===(idx[S.model]??0))
  );
}

function handleKey(e) {
  if (e.key==='Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
  autoResize(e.target);
}
function autoResize(el) { el.style.height='auto'; el.style.height=Math.min(el.scrollHeight,160)+'px'; }

$('msgInput').addEventListener('input', function(){ autoResize(this); });

$('fileInput').addEventListener('change', function(e) {
  const file = e.target.files[0]; if (!file) return;
  const reader = new FileReader();
  reader.onload = ev => {
    S.pendingImg = { dataUrl: ev.target.result, file };
    $('imgPrev').innerHTML = `<img src="${ev.target.result}" alt="preview"/><button onclick="clearImg()">✕</button>`;
  };
  reader.readAsDataURL(file); e.target.value = '';
});
function clearImg() { S.pendingImg = null; $('imgPrev').innerHTML = ''; }

$('btnNew').addEventListener('click', newChat);
$('btnToggle') && $('btnToggle').addEventListener('click', () => $('sidebar').classList.toggle('collapsed'));
$('btnShowChats').addEventListener('click', () => $('chatList').scrollIntoView({ behavior:'smooth' }));
$('btnMemory') && $('btnMemory').addEventListener('click', () => { closeAccountPopup(); addMemory(); });
$('userRow').addEventListener('click', openAccountPopup);
$('btnMobAccount') && $('btnMobAccount').addEventListener('click', openAccountPopup);
$('btnMobMenu') && $('btnMobMenu').addEventListener('click', () => {
  $('sidebar').classList.toggle('open');
  $('sidebarOverlay').classList.toggle('hidden', !$('sidebar').classList.contains('open'));
});

function closeSidebar() {
  if (window.innerWidth <= 768) {
    $('sidebar').classList.remove('open');
    $('sidebarOverlay').classList.add('hidden');
  }
}

// ── TEXT FORMAT ───────────────────────────────────────
function fmt(text) {
  if (!text) return '';
  let h = esc(text);
  h = h.replace(/```(\w*)\n?([\s\S]*?)```/g, (_,l,c) => `<pre><code>${c.trim()}</code></pre>`);
  h = h.replace(/`([^`]+)`/g, '<code>$1</code>');
  h = h.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  h = h.replace(/\*(.+?)\*/g, '<em>$1</em>');
  h = h.replace(/\n/g, '<br>');
  return h;
}

// ── INIT ──────────────────────────────────────────────
function initApp() {
  loadChats();
  $('userAva').textContent = S.user.username[0].toUpperCase();
  $('userName').textContent = S.user.username;
  updateCredHint();
  if (S.chats.length) {
    S.activeId = S.chats[0].id;
    S.model = activeChat()?.model || 'cronux';
    syncTabs();
  }
  renderSidebar();
  renderMessages();
}

(function boot() {
  getUsers();
  const s = localStorage.getItem('cx_s');
  if (s) {
    try { S.user = JSON.parse(s); $('authModal').classList.add('hidden'); initApp(); return; }
    catch(_) {}
  }
  const users = getUsers();
  if (users['fronz']) { startSession(users['fronz']); return; }
  $('authModal').classList.remove('hidden');
})();
