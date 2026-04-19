const API = 'http://localhost:3000/api';
const LABEL = { 'cronux':'CronuxAI', 'cronux-coder':'CronuxCoder', 'cronux-pro':'CronuxPro' };

// Suggestion chips после каждого AI ответа
const SUGGESTIONS = [
  ['Расскажи подробнее', 'Приведи пример', 'Как это работает?'],
  ['Объясни проще', 'Что дальше?', 'Дай альтернативу'],
  ['Покажи код', 'Сравни варианты', 'Какие плюсы и минусы?'],
];

let S = {
  user: null, chats: [], activeId: null,
  model: 'cronux', search: false, think: false,
  pendingImg: null, loading: false,
};

// ── UTILS ─────────────────────────────────────────────
const $ = id => document.getElementById(id);
const esc = s => String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const cap = s => s.charAt(0).toUpperCase() + s.slice(1);
const today = () => new Date().toISOString().split('T')[0];

// ── AUTH ──────────────────────────────────────────────
function getUsers() {
  const u = JSON.parse(localStorage.getItem('cx_u') || '{}');
  if (!u['fronz']) { u['fronz'] = { username:'Fronz', password:'fronz123', unlimited:true }; localStorage.setItem('cx_u', JSON.stringify(u)); }
  return u;
}
function login() {
  const n = $('loginUser').value.trim().toLowerCase(), p = $('loginPass').value;
  const u = getUsers()[n];
  if (!u || u.password !== p) return authErr('Неверные данные');
  startSession(u);
}
function register() {
  const n = $('regUser').value.trim().toLowerCase(), e = $('regEmail').value.trim(), p = $('regPass').value;
  if (!n||!e||!p) return authErr('Заполните все поля');
  const users = getUsers();
  if (users[n]) return authErr('Пользователь уже существует');
  users[n] = { username: cap(n), password: p, unlimited: false, credits: 100 };
  localStorage.setItem('cx_u', JSON.stringify(users));
  startSession(users[n]);
}
function startSession(u) {
  S.user = u; localStorage.setItem('cx_s', JSON.stringify(u));
  $('authModal').classList.add('hidden'); initApp();
}
function logout() {
  if (!confirm('Выйти из аккаунта?')) return;
  localStorage.removeItem('cx_s'); location.reload();
}
function authErr(m) { $('authError').textContent = m; setTimeout(() => $('authError').textContent = '', 3000); }
function switchTab(t) {
  $('loginForm').style.display = t==='login' ? '' : 'none';
  $('registerForm').style.display = t==='register' ? '' : 'none';
  document.querySelectorAll('.auth-tab').forEach((b,i) => b.classList.toggle('active', i===(t==='login'?0:1)));
}

// ── CREDITS ───────────────────────────────────────────
function getCredits() {
  if (S.user.unlimited) return null;
  const raw = localStorage.getItem(`cx_cr_${S.user.username.toLowerCase()}`);
  const c = raw ? JSON.parse(raw) : { cur:100, max:100, date:today() };
  if (c.date !== today()) { c.cur = c.max; c.date = today(); }
  return c;
}
function useCredit() {
  if (S.user.unlimited) return true;
  const c = getCredits(); if (c.cur <= 0) return false;
  c.cur--; localStorage.setItem(`cx_cr_${S.user.username.toLowerCase()}`, JSON.stringify(c));
  updateCredHint(); return true;
}
function updateCredHint() {
  const el = $('credHint');
  if (S.user.unlimited) { el.textContent = ''; return; }
  const c = getCredits(); el.textContent = `${c.cur}/${c.max} кредитов`;
}

// ── CHATS ─────────────────────────────────────────────
const chatsKey = () => `cx_chats_${S.user.username.toLowerCase()}`;
function loadChats() { S.chats = JSON.parse(localStorage.getItem(chatsKey()) || '[]'); }
function saveChats() { localStorage.setItem(chatsKey(), JSON.stringify(S.chats)); }

function newChat() {
  const id = Date.now().toString();
  S.chats.unshift({ id, title:'Новый чат', messages:[], model:S.model });
  S.activeId = id; saveChats(); renderSidebar(); renderMessages();
}
function switchChat(id) {
  S.activeId = id;
  const c = activeChat(); if (c) { S.model = c.model; syncTabs(); }
  renderSidebar(); renderMessages();
}
function deleteChat(id, e) {
  e.stopPropagation();
  S.chats = S.chats.filter(c => c.id !== id);
  if (S.activeId === id) S.activeId = S.chats[0]?.id || null;
  saveChats(); renderSidebar(); renderMessages();
}
const activeChat = () => S.chats.find(c => c.id === S.activeId) || null;

// ── SIDEBAR ───────────────────────────────────────────
function renderSidebar() {
  const list = $('chatList');
  if (!S.chats.length) { list.innerHTML = '<div style="padding:12px 10px;font-size:12px;color:var(--t3)">Нет чатов</div>'; return; }

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

  if (!chat || !chat.messages.length) {
    cont.innerHTML = ''; cont.appendChild(wel);
    wel.style.display = ''; tb.classList.add('hidden'); return;
  }

  wel.style.display = 'none'; tb.classList.remove('hidden');
  $('topbarModel').textContent = LABEL[S.model] || 'CronuxAI';
  cont.innerHTML = '';

  chat.messages.forEach((m, i) => {
    cont.appendChild(buildMsg(m));
    // Chips только после последнего AI сообщения
    if (m.role === 'assistant' && i === chat.messages.length - 1) {
      cont.appendChild(buildChips());
    }
  });
  cont.scrollTop = cont.scrollHeight;
}

function buildMsg(m) {
  const div = document.createElement('div');
  div.className = `message ${m.role}`;
  const isUser = m.role === 'user';

  const avaHtml = isUser
    ? `<div class="msg-ava">${S.user.username[0].toUpperCase()}</div>`
    : `<div class="msg-ava"><img src="logo.png" alt="AI" /></div>`;

  let body = '';
  if (m.imgUrl) body += `<img src="${m.imgUrl}" class="msg-image" alt="img" />`;
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

  div.innerHTML = `${avaHtml}<div class="msg-body"><div class="msg-name">${isUser ? esc(S.user.username) : LABEL[m.model||S.model]||'CronuxAI'}</div>${body}</div>`;
  return div;
}

function buildChips() {
  const set = SUGGESTIONS[Math.floor(Math.random() * SUGGESTIONS.length)];
  const div = document.createElement('div');
  div.className = 'suggestions';
  div.innerHTML = set.map(s => `<button class="sug-chip" onclick="sendQuick('${esc(s)}')">${esc(s)}</button>`).join('');
  return div;
}

function addTyping() {
  const div = document.createElement('div');
  div.className = 'message assistant'; div.id = 'typing';
  div.innerHTML = `<div class="msg-ava"><img src="logo.png" alt="AI" /></div>
    <div class="msg-body"><div class="msg-name">${LABEL[S.model]}</div>
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

  if (!S.activeId) newChat();
  if (!useCredit()) return alert('Кредиты исчерпаны');
  trackMsg();

  const chat = activeChat();
  if (!chat.messages.length) { chat.title = text.slice(0,45) || 'Изображение'; renderSidebar(); }

  const userMsg = { role:'user', content:text, imgUrl:img?.dataUrl||null, model:S.model, ts:Date.now() };
  chat.messages.push(userMsg); saveChats();

  input.value = ''; autoResize(input); clearImg();
  $('welcome').style.display = 'none';
  $('topbar').classList.remove('hidden');
  $('topbarModel').textContent = LABEL[S.model];

  // Убрать старые chips
  document.querySelectorAll('.suggestions').forEach(el => el.remove());

  const cont = $('messages');
  cont.appendChild(buildMsg(userMsg));
  cont.scrollTop = cont.scrollHeight;

  S.loading = true; $('sendBtn').disabled = true; addTyping();

  try {
    let resp;
    if (img) {
      const ocrText = await doOCR(img.file);
      const combined = text ? `${text}\n\n[OCR текст с фото]:\n${ocrText}` : ocrText;
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
  // Убрать последний AI ответ и chips
  document.querySelectorAll('.suggestions').forEach(el => el.remove());
  const lastAI = $('messages').querySelector('.message.assistant:last-of-type');
  if (lastAI) lastAI.remove();
  chat.messages = chat.messages.filter((m,i) => !(m.role==='assistant' && i===chat.messages.length-1));
  const lastUser = chat.messages[chat.messages.length-1];
  if (!lastUser) return;
  S.loading = true; $('sendBtn').disabled = true; addTyping();
  try {
    const resp = await apiChat(lastUser.content, chat.messages.slice(0,-1));
    removeTyping();
    const aiMsg = { role:'assistant', content:resp.text, model:S.model, ts:Date.now() };
    chat.messages.push(aiMsg); saveChats();
    $('messages').appendChild(buildMsg(aiMsg));
    $('messages').appendChild(buildChips());
    $('messages').scrollTop = $('messages').scrollHeight;
  } catch(e) { removeTyping(); }
  finally { S.loading = false; $('sendBtn').disabled = false; }
}

function copyMsg(btn) {
  const text = btn.closest('.msg-body').querySelector('.msg-text')?.innerText || '';
  navigator.clipboard.writeText(text).then(() => { btn.textContent = '✅'; setTimeout(() => btn.textContent = '📋', 1500); });
}

// ── API ───────────────────────────────────────────────
async function apiChat(text, history) {
  const memCtx = getMemoryContext();
  const res = await fetch(`${API}/chat`, {
    method:'POST', headers:{'Content-Type':'application/json'},
    body: JSON.stringify({
      message: text + memCtx,
      model: S.model,
      history: history.map(m=>({role:m.role,content:m.content}))
    }),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const d = await res.json();
  return { text: d.response, searchUsed: false };
}

async function apiWithSearch(text, history) {
  const sr = await fetch(`${API}/search`, { method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({query:text}) });
  const sd = sr.ok ? await sr.json() : { results:'' };
  const aug = sd.results ? `Вопрос: ${text}\n\nРезультаты поиска:\n${sd.results}\n\nОтветь на основе этих данных.` : text;
  const r = await apiChat(aug, history);
  return { ...r, searchUsed: true };
}

async function doOCR(file) {
  try {
    const fd = new FormData(); fd.append('image', file);
    const r = await fetch(`${API}/ocr`, { method:'POST', body:fd });
    if (r.ok) { const d = await r.json(); if (d.text) return d.text; }
  } catch(_) {}
  try { const r = await Tesseract.recognize(file,'rus+eng',{logger:()=>{}}); return r.data.text||'(текст не распознан)'; }
  catch(_) { return '(OCR недоступен)'; }
}

// ── UI ────────────────────────────────────────────────
function toggleSearch() { S.search = !S.search; $('pillSearch').classList.toggle('on', S.search); }
function toggleThink()  { S.think  = !S.think;  $('pillThink').classList.toggle('on', S.think); }

function setTab(model, btn) {
  S.model = model;
  document.querySelectorAll('.model-tab').forEach(b => b.classList.remove('active'));
  btn.classList.add('active');
  const c = activeChat(); if (c) { c.model = model; saveChats(); }
}
function syncTabs() {
  const idx = {'cronux':0,'cronux-coder':1,'cronux-pro':2};
  document.querySelectorAll('.model-tab').forEach((b,i) => b.classList.toggle('active', i===(idx[S.model]??0)));
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
    $('imgPrev').innerHTML = `<img src="${ev.target.result}" alt="preview" /><button onclick="clearImg()">✕</button>`;
  };
  reader.readAsDataURL(file); e.target.value = '';
});
function clearImg() { S.pendingImg = null; $('imgPrev').innerHTML = ''; }

$('btnNew').addEventListener('click', newChat);

// Sidebar toggle desktop
$('btnToggle') && $('btnToggle').addEventListener('click', () => $('sidebar').classList.toggle('collapsed'));
$('btnShowChats').addEventListener('click', () => $('chatList').scrollIntoView({ behavior: 'smooth' }));

// Mobile sidebar
$('btnMobMenu').addEventListener('click', () => {
  $('sidebar').classList.toggle('open');
  $('sidebarOverlay').classList.toggle('hidden', !$('sidebar').classList.contains('open'));
});
function closeSidebar() {
  $('sidebar').classList.remove('open');
  $('sidebarOverlay').classList.add('hidden');
}

// Account popup
$('userRow').addEventListener('click', openAccountPopup);
$('btnMobAccount') && $('btnMobAccount').addEventListener('click', openAccountPopup);

function openAccountPopup() {
  const popup = $('accountPopup');
  popup.classList.remove('hidden');
  $('popup-overlay') && $('popup-overlay').classList.remove('hidden');
  $('accountPopupOverlay').classList.remove('hidden');

  // Заполнить данные
  $('apAva').textContent = S.user.username[0].toUpperCase();
  $('apName').textContent = S.user.username;
  $('apPlan').textContent = S.user.unlimited ? 'Pro · Безлимит ∞' : 'Free';

  // Credits
  if (S.user.unlimited) {
    $('apCredits').textContent = '∞';
    $('apCredBar').style.width = '100%';
  } else {
    const c = getCredits();
    $('apCredits').textContent = `${c.cur}/${c.max}`;
    $('apCredBar').style.width = `${(c.cur/c.max)*100}%`;
  }

  // Messages today
  const msgsKey = `cx_msgs_${S.user.username.toLowerCase()}_${today()}`;
  const msgsToday = parseInt(localStorage.getItem(msgsKey) || '0');
  const maxMsgs = S.user.unlimited ? 999 : 50;
  $('apMsgsToday').textContent = `${msgsToday}${S.user.unlimited ? '' : '/'+maxMsgs}`;
  $('apMsgsBar').style.width = S.user.unlimited ? `${Math.min(msgsToday/10,100)}%` : `${Math.min(msgsToday/maxMsgs*100,100)}%`;

  // Searches
  const srchKey = `cx_srch_${S.user.username.toLowerCase()}_${today()}`;
  const searches = parseInt(localStorage.getItem(srchKey) || '0');
  $('apSearches').textContent = searches;
  $('apSearchBar').style.width = `${Math.min(searches/20*100,100)}%`;

  // Chats total
  const total = S.chats.length;
  $('apChatsTotal').textContent = total;
  $('apChatsBar').style.width = `${Math.min(total/20*100,100)}%`;

  renderMemoryList();
}

function closeAccountPopup() {
  $('accountPopup').classList.add('hidden');
  $('accountPopupOverlay').classList.add('hidden');
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

function addMemory() {
  $('memoryModal').classList.remove('hidden');
  $('memInput').value = '';
  setTimeout(() => $('memInput').focus(), 100);
}

function saveMemory() {
  const text = $('memInput').value.trim();
  if (!text) return;
  const mem = getMemory();
  mem.push(text);
  saveMemoryData(mem);
  closeMemoryModal();
  renderMemoryList();
}

function deleteMemory(i) {
  const mem = getMemory();
  mem.splice(i, 1);
  saveMemoryData(mem);
  renderMemoryList();
}

function closeMemoryModal() { $('memoryModal').classList.add('hidden'); }

$('btnMemory') && $('btnMemory').addEventListener('click', () => {
  closeAccountPopup();
  addMemory();
});

// Трекинг сообщений
function trackMsg() {
  const k = `cx_msgs_${S.user.username.toLowerCase()}_${today()}`;
  localStorage.setItem(k, (parseInt(localStorage.getItem(k)||'0')+1).toString());
}
function trackSearch() {
  const k = `cx_srch_${S.user.username.toLowerCase()}_${today()}`;
  localStorage.setItem(k, (parseInt(localStorage.getItem(k)||'0')+1).toString());
}

// Добавить память в системный промпт
function getMemoryContext() {
  const mem = getMemory();
  if (!mem.length) return '';
  return `\n\n[Память о пользователе]:\n${mem.map(m=>'- '+m).join('\n')}`;
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
  if (S.chats.length) { S.activeId = S.chats[0].id; S.model = activeChat()?.model||'cronux'; syncTabs(); }
  renderSidebar(); renderMessages();
}

(function boot() {
  getUsers();
  const s = localStorage.getItem('cx_s');
  if (s) { try { S.user = JSON.parse(s); $('authModal').classList.add('hidden'); initApp(); return; } catch(_){} }
  // Автологин под Fronz для быстрого старта
  const users = getUsers();
  if (users['fronz']) { startSession(users['fronz']); return; }
  $('authModal').classList.remove('hidden');
})();
