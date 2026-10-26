// SAP FICO EXPERT : navigation commune et code d'accès. Aucune clé ici : le code reste sur l'appareil.
(function () {
  var KEY = 'yaasap_fiches_code', A = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  var page = (location.pathname.split('/').pop() || 'index.html');

  /* ---------- code d'accès (même format que les fiches : blocs de 26 caractères) ---------- */
  function norm(c) { return String(c || '').toUpperCase().replace(/[^A-Z2-7]/g, ''); }
  function chunks(s) { var o = []; for (var i = 0; i + 26 <= s.length; i += 26) o.push(s.slice(i, i + 26)); return o; }
  function get() { try { return localStorage.getItem(KEY) || ''; } catch (e) { return ''; } }
  function save(c) { // ajoute les nouveaux blocs sans écraser les codes déjà enregistrés
    var seen = {}, out = [];
    chunks(norm(get())).concat(chunks(norm(c))).forEach(function (x) { if (!seen[x]) { seen[x] = 1; out.push(x); } });
    try { localStorage.setItem(KEY, out.join('')); } catch (e) {}
    return out.length;
  }
  function clear() { try { localStorage.removeItem(KEY); } catch (e) {} }

  function B(s) { var b = atob(s), a = new Uint8Array(b.length); for (var i = 0; i < b.length; i++) a[i] = b.charCodeAt(i); return a; }
  function B32(s) {
    var bits = 0, v = 0, o = [];
    for (var i = 0; i < s.length; i++) { var x = A.indexOf(s.charAt(i)); if (x < 0) return null; v = (v << 5) | x; bits += 5; if (bits >= 8) { o.push((v >>> (bits - 8)) & 255); bits -= 8; v &= (1 << bits) - 1; } }
    return new Uint8Array(o);
  }
  async function dec(kb, blob) {
    var k = await crypto.subtle.importKey('raw', kb, 'AES-GCM', false, ['decrypt']), d = B(blob);
    return new Uint8Array(await crypto.subtle.decrypt({ name: 'AES-GCM', iv: d.slice(0, 12) }, k, d.slice(12)));
  }
  async function open(code, D) { // renvoie le HTML de la fiche, ou null si le code ne l'ouvre pas
    var s = norm(code);
    if (!window.crypto || !crypto.subtle || s.length < 26 || s.length % 26) return null;
    for (var i = 0; i < s.length; i += 26) {
      var kb = B32(s.slice(i, i + 26)); if (!kb || kb.length !== 16) continue;
      try { return new TextDecoder().decode(await dec(kb, D.e)); } catch (e) {}
      try { var fk = await dec(kb, D.w); return new TextDecoder().decode(await dec(fk, D.e)); } catch (e) {}
    }
    return null;
  }

  /* ---------- liste des fiches : lue dans catalogue.html, donc toujours à jour ---------- */
  var listP;
  function fiches() {
    return listP || (listP = (async function () {
      try { var c = sessionStorage.getItem('fs_list'); if (c) return JSON.parse(c); } catch (e) {}
      try {
        var t = await (await fetch('catalogue.html')).text();
        var d = new DOMParser().parseFromString(t, 'text/html');
        var l = [].map.call(d.querySelectorAll('ul.list a'), function (a) {
          return { h: a.getAttribute('href'), k: (a.querySelector('.k') || {}).textContent || '', t: (a.querySelector('b') || {}).textContent || a.textContent };
        });
        try { sessionStorage.setItem('fs_list', JSON.stringify(l)); } catch (e) {}
        return l;
      } catch (e) { return []; }
    })());
  }

  // Cherche les fiches ouvertes par ce code. full=false : s'arrête à la première (suffit pour valider un code).
  async function scan(code, full, cb) {
    var l = await fiches(), hit = [], i = 0, n = 0;
    async function w() {
      while (i < l.length) {
        var f = l[i++];
        try {
          var t = await (await fetch(f.h)).text();
          var m = t.match(/<script type="application\/json" id="d">([\s\S]*?)<\/script>/);
          if (m && await open(code, JSON.parse(m[1]))) hit.push(f);
        } catch (e) {}
        n++; if (cb) cb(n, l.length, hit.length);
        if (hit.length && !full) i = l.length;
      }
    }
    await Promise.all([1, 2, 3, 4, 5, 6].map(w));
    return hit.sort(function (a, b) { return l.indexOf(a) - l.indexOf(b); });
  }

  window.FicoSite = { get: get, save: save, clear: clear, norm: norm, open: open, fiches: fiches, scan: scan };

  /* ---------- à partir d'ici : habillage des pages fiches et catalogue ---------- */
  var back = document.querySelector('a.back');
  if (!back) return;

  var css = document.createElement('style');
  css.textContent =
    '.fs-bar{display:flex;flex-wrap:wrap;align-items:center;gap:6px 16px;padding:12px 0 0;font:600 13.5px var(--f-body,system-ui)}' +
    '.fs-bar a{color:var(--mute,#5b6a7e);text-decoration:none}.fs-bar a:hover{color:var(--c,#0b5fc2)}' +
    '.fs-bar .sp{flex:1}.fs-bar .st{border:1px solid var(--line,#d9dfe7);border-radius:999px;padding:3px 11px;background:var(--panel,#fff)}' +
    '.fs-bar .st.on{border-color:var(--c,#0b5fc2);color:var(--c,#0b5fc2)}' +
    '.fs-pn{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:22px}.fs-pn a{display:block;min-width:0;background:var(--panel,#fff);border:1px solid var(--line,#d9dfe7);border-radius:10px;padding:10px 14px;color:var(--ink,#142033);text-decoration:none}' +
    '.fs-pn a:hover{border-color:var(--c,#0b5fc2)}.fs-pn small{display:block;font:700 11px var(--f-mono,monospace);letter-spacing:.1em;text-transform:uppercase;color:var(--mute,#5b6a7e)}' +
    '.fs-pn b{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;font-weight:600;font-size:14.5px;line-height:1.3}.fs-pn .nx{text-align:right;grid-column:2}' +
    '.fs-find{width:100%;margin-top:20px;font:500 15px var(--f-body,system-ui);padding:12px 14px;border:1px solid var(--line,#d9dfe7);border-radius:10px;background:var(--panel,#fff);color:var(--ink,#142033)}' +
    '.fs-cnt{font-size:13.5px;color:var(--mute,#5b6a7e);margin:8px 0 0}' +
    '.fs-code{background:var(--panel,#fff);border:1px solid var(--line,#d9dfe7);border-top:5px solid var(--gold,#e8a13a);border-radius:12px;padding:16px 20px;margin-top:16px}' +
    '.fs-code p{margin:0 0 8px}.fs-code form{display:flex;gap:8px;flex-wrap:wrap}' +
    '.fs-code input{flex:1 1 240px;min-width:0;font:500 14px var(--f-mono,monospace);padding:11px 12px;border:1px solid var(--line,#d9dfe7);border-radius:8px;background:var(--bg,#f2f4f7);color:var(--ink,#142033)}' +
    '.fs-code button{background:var(--c,#0b5fc2);color:#fff;border:0;border-radius:8px;padding:11px 16px;font:700 15px var(--f-body,system-ui);cursor:pointer}' +
    '.fs-code button.g{background:transparent;color:var(--c,#0b5fc2);border:1px solid var(--line,#d9dfe7)}.fs-code button:disabled{opacity:.55;cursor:wait}' +
    '.fs-msg{font-size:14px;min-height:1.2em;margin-top:8px;color:#c0392b}.fs-msg.ok{color:#2d6a4f}';
  document.head.appendChild(css);

  var isCat = page === 'catalogue.html';
  var has = !!norm(get());

  // barre de navigation à la place du lien « retour »
  var bar = document.createElement('nav');
  bar.className = 'fs-bar'; bar.setAttribute('aria-label', 'Navigation');
  bar.innerHTML = (isCat ? '<a href="index.html">← Accueil</a>' : '<a href="catalogue.html">← Catalogue</a><a href="index.html">Accueil</a>') +
    '<span class="sp"></span><a class="st' + (has ? ' on' : '') + '" href="acces.html' + (has ? '' : '#code') + '">' +
    (has ? '✓ Code enregistré' : 'J’ai un code') + '</a>';
  back.replaceWith(bar);

  if (isCat) {
    // saisie du code + recherche dans les 97 fiches
    var tarifs = document.getElementById('tarifs'), ul = document.querySelector('ul.list');
    if (tarifs) {
      var box = document.createElement('div'); box.className = 'fs-code';
      box.innerHTML = has
        ? '<p><b>Code enregistré sur cet appareil.</b> Il ouvre automatiquement les fiches concernées.</p><p><a href="acces.html">Voir mes fiches débloquées</a></p>'
        : '<p><b>Tu as déjà un code ?</b> Saisis-le une fois : il s’applique ensuite à toutes tes fiches.</p>' +
          '<form id="fs-f" novalidate><input id="fs-c" type="text" autocomplete="off" spellcheck="false" placeholder="Ton code d’accès" aria-label="Code d’accès"><button type="submit">Enregistrer</button></form><div class="fs-msg" id="fs-m" role="status"></div>';
      tarifs.parentNode.insertBefore(box, tarifs);
      var f = document.getElementById('fs-f');
      if (f) f.addEventListener('submit', async function (ev) {
        ev.preventDefault();
        var c = document.getElementById('fs-c').value, m = document.getElementById('fs-m'), b = f.querySelector('button');
        m.className = 'fs-msg'; m.textContent = 'Vérification…'; b.disabled = true;
        var s = norm(c);
        if (s.length < 26 || s.length % 26) { m.textContent = 'Code incomplet : il contient 26 caractères (lettres A–Z et chiffres 2–7).'; b.disabled = false; return; }
        var hit = await scan(c, false);
        if (!hit.length) { m.textContent = 'Ce code n’ouvre aucune fiche. Vérifie-le ou écris-nous.'; b.disabled = false; return; }
        save(c); m.className = 'fs-msg ok'; m.textContent = 'Code enregistré. Tes fiches s’ouvrent directement.';
        setTimeout(function () { location.href = hit[0].h; }, 700);
      });
    }
    if (ul) {
      var q = document.createElement('input');
      q.type = 'search'; q.className = 'fs-find'; q.placeholder = 'Rechercher une transaction ou un mot (FB60, paiement, immobilisations…)'; q.setAttribute('aria-label', 'Rechercher une fiche');
      var cnt = document.createElement('p'); cnt.className = 'fs-cnt'; cnt.setAttribute('aria-live', 'polite');
      ul.parentNode.insertBefore(q, ul); ul.parentNode.insertBefore(cnt, ul);
      var lis = [].slice.call(ul.children);
      q.addEventListener('input', function () {
        var t = q.value.trim().toLowerCase(), n = 0;
        lis.forEach(function (li) { var ok = !t || li.textContent.toLowerCase().indexOf(t) > -1; li.hidden = !ok; if (ok) n++; });
        cnt.textContent = t ? (n ? n + ' fiche' + (n > 1 ? 's' : '') : 'Aucune fiche ne correspond.') : '';
      });
    }
    return;
  }

  // fiches voisines, d'après l'ordre du catalogue
  fiches().then(function (l) {
    var i = -1; l.forEach(function (f, k) { if (f.h === page) i = k; });
    var foot = document.querySelector('footer'); if (i < 0 || !foot) return;
    function card(f, cls, lab) { return '<a class="' + cls + '" href="' + f.h + '"><small>' + lab + '</small><b>' + f.t.replace(/</g, '&lt;') + '</b></a>'; }
    var pn = document.createElement('nav'); pn.className = 'fs-pn'; pn.setAttribute('aria-label', 'Fiches voisines');
    pn.innerHTML = (i > 0 ? card(l[i - 1], 'pv', '← Précédente') : '') + (i < l.length - 1 ? card(l[i + 1], 'nx', 'Suivante →') : '');
    foot.parentNode.insertBefore(pn, foot);
  });
})();
