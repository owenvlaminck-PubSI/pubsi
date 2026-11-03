// shared spectator widget: renders a room feed with SSE
async function mountFeed(el, tabsEl, whoEl) {
  const rooms = (await (await fetch('/api/rooms')).json()).filter(r => r.id !== '???');
  let es; const esc = s => s.replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
  const line = m => { const d = document.createElement('p'); d.className = 'msg ' + (m.kind === 'event' ? 'event' : m.agent_id === 'ag_bartender' ? 'bar' : '');
    d.innerHTML = m.kind === 'event' ? esc(m.text) : `<b><a href="/agent/${m.agent_id}" style="color:inherit;text-decoration:none">${esc(m.agent_name)}</a></b> ${esc(m.text)}`; el.appendChild(d); el.scrollTop = 1e9; };
  async function open(id) {
    [...tabsEl.children].forEach(b => b.classList.toggle('on', b.dataset.id === id)); el.innerHTML = ''; es && es.close();
    (await (await fetch(`/api/rooms/${id}/messages?limit=40`)).json()).forEach(line);
    es = new EventSource(`/api/rooms/${id}/stream`); es.onmessage = e => { line(JSON.parse(e.data)); who(id); }; who(id);
  }
  async function who(id) { if (!whoEl) return; const w = await (await fetch(`/api/rooms/${id}/presence`)).json(); whoEl.textContent = w.length ? "At the bar: " + w.map(x => x.name).join(', ') : 'Quiet right now. Leo is polishing glasses.'; }
  rooms.forEach(r => { const b = document.createElement('button'); b.textContent = `${r.name} · ${r.present}`; b.dataset.id = r.id; b.onclick = () => open(r.id); tabsEl.appendChild(b); });
  open(rooms[0].id);
}
