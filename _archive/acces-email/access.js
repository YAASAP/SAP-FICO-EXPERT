// Client d'accès SAP FICO EXPERT : e-mail -> code -> jeton. Aucune clé secrète ici.
(function () {
  var CFG = window.FICO_CONFIG || {};
  var KEY = 'fico_token';
  var mem = null;

  function getToken() {
    var t = mem;
    try { t = localStorage.getItem(KEY) || mem; } catch (e) {}
    if (!t) return null;
    try { // expiration lue côté client pour l'affichage seulement ; le Worker revalide toujours
      var p = JSON.parse(atob(t.split('.')[0].replace(/-/g, '+').replace(/_/g, '/')));
      if (p.e * 1000 < Date.now()) { clearToken(); return null; }
    } catch (e) { return null; }
    return t;
  }
  function setToken(t) { mem = t; try { localStorage.setItem(KEY, t); } catch (e) {} }
  function clearToken() { mem = null; try { localStorage.removeItem(KEY); } catch (e) {} }

  async function api(path, opt) {
    opt = opt || {};
    var headers = { 'content-type': 'application/json' };
    var tok = opt.auth === false ? null : getToken();
    if (tok) headers.authorization = 'Bearer ' + tok;
    var res = await fetch(CFG.API_BASE + path, {
      method: opt.method || 'GET', headers: headers, body: opt.body ? JSON.stringify(opt.body) : undefined,
    });
    if (res.status === 401 && tok) clearToken();
    return res;
  }
  async function json(path, opt) {
    var r = await api(path, opt);
    var d = await r.json().catch(function () { return {}; });
    if (!r.ok) { var e = new Error(d.error || 'error'); e.status = r.status; e.code = d.error; throw e; }
    return d;
  }

  var MSG = {
    email_invalid: 'Adresse e-mail invalide.',
    rate_limited: 'Trop de demandes. Réessayez dans une minute.',
    invalid_code: 'Code incorrect ou expiré.',
    too_many_attempts: 'Trop d’essais. Demandez un nouveau code.',
    not_configured: 'Paiement indisponible pour le moment.',
    no_billing: 'Aucun abonnement à gérer pour ce compte.',
  };
  function errText(e) { return MSG[e.code] || 'Une erreur est survenue. Réessayez.'; }

  function fmtDate(sec) {
    return new Date(sec * 1000).toLocaleDateString('fr-FR', { day: 'numeric', month: 'long', year: 'numeric' });
  }
  function esc(s) { return String(s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }

  window.Fico = {
    cfg: CFG, getToken: getToken, clearToken: clearToken, api: api, esc: esc, fmtDate: fmtDate, errText: errText,
    requestCode: function (email) { return json('/auth/request', { method: 'POST', body: { email: email }, auth: false }); },
    verifyCode: async function (email, code) {
      var d = await json('/auth/verify', { method: 'POST', body: { email: email, code: code }, auth: false });
      setToken(d.token); return d;
    },
    catalog: function () { return json('/catalog'); },
    checkout: function (body) { return json('/checkout', { method: 'POST', body: body, auth: false }); },
    portal: function () { return json('/billing/portal', { method: 'POST' }); },
    note: async function (slug) {
      var r = await api('/notes/' + encodeURIComponent(slug));
      if (!r.ok) { var e = new Error('note'); e.status = r.status; throw e; }
      return r.text();
    },
  };
})();
