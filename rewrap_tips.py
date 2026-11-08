#!/usr/bin/env python3
"""
rewrap_tips.py : le code « catalogue complet » ouvre aussi les 13 tips & pièges.

Principe : chaque tip contient deux blocs chiffrés.
  e = contenu de la fiche, chiffré avec la clé propre du tip (le code individuel)
  w = clé du tip, chiffrée avec la clé « pack »
Ce script remplace la clé « pack » (ancien code pack des tips) par ta clé du
catalogue complet : w est refait, e ne change pas. Après ça :
  - le code catalogue complet ouvre les tips (comme les 97 fiches)
  - les 13 codes individuels continuent de fonctionner
  - l'ancien code pack des tips ne fonctionne plus

À lancer depuis ton clone local du dépôt SAP-FICO-EXPERT. Aucun secret n'est écrit
dans les fichiers ni affiché. Ne committe jamais les codes.

  pip install cryptography
  python rewrap_tips.py                (les codes sont demandés, saisie masquée)
  python rewrap_tips.py --dry-run      (vérifie tout sans rien modifier)

Puis : git add tips-pieges && git commit -m "Tips : ouverts par le code catalogue" && git push
"""
import argparse, base64, getpass, glob, json, os, re, sys

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    from cryptography.exceptions import InvalidTag
except ImportError:
    sys.exit("Module manquant : lance d'abord  pip install cryptography")

A = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
JSON_RE = re.compile(r'(<script type="application/json" id="d">)([\s\S]*?)(</script>)')


def norm(c):
    return re.sub(r"[^A-Z2-7]", "", str(c).upper())


def b32(s):  # même décodage que site.js
    bits, v, out = 0, 0, []
    for ch in s:
        v = (v << 5) | A.index(ch)
        bits += 5
        if bits >= 8:
            out.append((v >> (bits - 8)) & 255)
            bits -= 8
            v &= (1 << bits) - 1
    return bytes(out)


def key_from(code, label):
    s = norm(code)
    if len(s) != 26:
        sys.exit(f"{label} : 26 caractères attendus (lettres A-Z et chiffres 2-7), {len(s)} reçus. "
                 "Un seul code à la fois, sans espace en trop.")
    return b32(s)


def dec(key, blob):
    d = base64.b64decode(blob)
    return AESGCM(key).decrypt(d[:12], d[12:], None)


def enc(key, data):
    iv = os.urandom(12)
    return base64.b64encode(iv + AESGCM(key).encrypt(iv, data, None)).decode()


def read_json(path):
    t = open(path, encoding="utf-8").read()
    m = JSON_RE.search(t)
    if not m:
        return t, None, None
    try:
        return t, m, json.loads(m.group(2))
    except ValueError:
        return t, m, None


def opens(D, key):
    """True si `key` ouvre la fiche : soit directement (code individuel), soit via w (code pack / catalogue)."""
    try:
        dec(key, D["e"]); return True
    except (InvalidTag, ValueError, KeyError):
        pass
    try:
        fk = dec(key, D["w"]); dec(fk, D["e"]); return True
    except (InvalidTag, ValueError, KeyError):
        return False


def main():
    ap = argparse.ArgumentParser(description="Le code catalogue ouvre aussi les tips.")
    ap.add_argument("--dir", default="tips-pieges", help="dossier des tips (défaut : tips-pieges)")
    ap.add_argument("--ref", help="une fiche du catalogue pour vérifier le code (défaut : <dir>/../f110.html)")
    ap.add_argument("--dry-run", action="store_true", help="vérifie tout sans modifier les fichiers")
    ap.add_argument("--catalogue-code", help="évite la saisie masquée (visible dans l'historique du shell)")
    ap.add_argument("--pack-code", help="idem pour l'ancien code pack des tips")
    a = ap.parse_args()

    cat = key_from(a.catalogue_code or getpass.getpass("Code catalogue complet (14,90 €) : "), "Code catalogue")
    old = key_from(a.pack_code or getpass.getpass("Ancien code PACK des tips (fichier codes_tips.txt) : "), "Code pack")

    # 1. Sécurité : le code catalogue doit vraiment ouvrir une fiche du catalogue.
    ref = a.ref or os.path.join(a.dir, "..", "f110.html")
    if not os.path.isfile(ref):
        sys.exit(f"Fiche de référence introuvable : {ref}. Lance le script depuis la racine du clone, ou passe --ref.")
    _, _, Dref = read_json(ref)
    if not Dref or not opens(Dref, cat):
        sys.exit("STOP : ce code catalogue n'ouvre pas la fiche de référence. Rien n'a été modifié. "
                 "Vérifie que c'est bien le code « catalogue complet ».")
    print(f"Code catalogue vérifié sur {os.path.basename(ref)}.")

    # 2. Calcul en mémoire pour tous les tips : on n'écrit rien si un seul échoue.
    todo, done = [], []
    for p in sorted(glob.glob(os.path.join(a.dir, "*.html"))):
        t, m, D = read_json(p)
        if not D or "e" not in D or "w" not in D:
            continue
        if opens({"e": D["e"], "w": D["w"]}, cat) and not _opens_direct(D, cat):
            done.append(p); continue
        try:
            fk = dec(old, D["w"])
            dec(fk, D["e"])
        except (InvalidTag, ValueError):
            sys.exit(f"STOP : l'ancien code pack n'ouvre pas {os.path.basename(p)}. Rien n'a été modifié.")
        w2 = enc(cat, fk)
        dec(dec(cat, w2), D["e"])  # contrôle d'aller-retour
        newjson = json.dumps({"e": D["e"], "w": w2})
        todo.append((p, t[:m.start(2)] + newjson + t[m.end(2):], D["e"]))

    print(f"{len(todo)} tip(s) à mettre à jour, {len(done)} déjà ouverts par le code catalogue.")
    if a.dry_run:
        print("Mode essai : aucun fichier modifié.")
        return
    for p, new, _ in todo:
        open(p, "w", encoding="utf-8", newline="").write(new)

    # 3. Relecture finale
    bad = 0
    for p in glob.glob(os.path.join(a.dir, "*.html")):
        _, _, D = read_json(p)
        if D and "w" in D and not opens(D, cat):
            bad += 1; print("ÉCHEC de relecture :", os.path.basename(p))
    if bad:
        sys.exit("Relecture en échec : restaure avec  git checkout -- " + a.dir)
    print("OK. Le code catalogue ouvre tous les tips. Fais maintenant :")
    print('  git add tips-pieges && git commit -m "Tips : ouverts par le code catalogue" && git push')


def _opens_direct(D, key):
    try:
        dec(key, D["e"]); return True
    except (InvalidTag, ValueError):
        return False


if __name__ == "__main__":
    main()
