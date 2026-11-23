# -*- coding: utf-8 -*-
import re, json, sys, os
sys.path.insert(0, os.path.dirname(__file__))
import site_en_maps as M
os.chdir('/home/claude/sap-fico-expert')
TRANSLATED = {'index.html','catalogue.html','formations.html','acces.html','confidentialite.html'}
def tr(s, m):
    for k in sorted(m, key=len, reverse=True):
        s = s.replace(k, m[k])
    return s
def fix_links(s):
    def rep(mm):
        attr, url = mm.group(1), mm.group(2)
        if re.match(r'(https?:|#|mailto:|data:|\' ?\+|\+)', url) or url.startswith("'"): return mm.group(0)
        base = url.split('#')[0].split('?')[0]
        if base in TRANSLATED or base == '' : return mm.group(0)
        if base == 'site.js': return mm.group(0)
        return '%s="../%s"' % (attr, url)
    return re.sub(r'\b(href|src)="([^"]*)"', rep, s)
def head(s, page):
    s = s.replace('<html lang="fr"', '<html lang="en"')
    if 'rel="canonical"' in s:
        s = re.sub(r'(rel="canonical" href=")([^"]*)"', lambda m: m.group(1)+m.group(2).replace('github.io/SAP-FICO-EXPERT/','github.io/SAP-FICO-EXPERT/en/')+'"', s)
    return s
def out(name, s):
    open('en/'+name, 'w', encoding='utf-8').write(s)
# catalogue
cat = open('catalogue.html', encoding='utf-8').read()
cen = json.load(open('_ios/FicoExpert/catalogue_en.json', encoding='utf-8'))
items = cen if isinstance(cen, list) else cen.get('items', cen)
byid = {}
for e in items:
    byid[e.get('id') or e.get('href','').replace('.html','')] = e
def li(mm):
    href = mm.group(1); id_ = href.replace('.html','')
    e = byid.get(id_)
    if not e: return mm.group(0)
    mod = e.get('module') or e.get('modules') or ''
    if isinstance(mod, list): mod = mod[0]
    return '<li><a href="%s"><span class="k">%s</span><b>%s</b><span class="i">%s</span></a></li>' % (href, mod, (e['code']+' : ' if e.get('code') else '')+e['title'], e.get('summary',''))
cat2 = re.sub(r'<li><a href="([^"]+)"><span class="k">[^<]*</span><b>[^<]*</b><span class="i">[^<]*</span></a></li>', li, cat)
cat2 = tr(cat2, M.CAT_CHROME)
cat2 = cat2.replace('97 fiches SAP FICO : transaction, étapes, pièges et contrôles. Aperçu gratuit, fiche complète sur accès.','97 SAP FICO notes: transaction, steps, pitfalls and checks. Free preview, full note with access.')
cat2 = cat2.replace('Fiches SAP FICO : 97 transactions et paramétrages expliqués','SAP FICO notes: 97 transactions and configurations explained')
out('catalogue.html', head(fix_links(cat2), 'catalogue.html'))
for name, mp in [('index.html', M.INDEX), ('acces.html', M.ACCES), ('formations.html', M.FORM), ('confidentialite.html', M.PRIV)]:
    s = open(name, encoding='utf-8').read()
    s = tr(s, mp); s = head(fix_links(s), name)
    out(name, s)
js = open('site.js', encoding='utf-8').read()
js = tr(js, M.SITEJS)
out('site.js', js)
print('done')
