# SAP FICO EXPERT

Site de fiches, d'atlas et de modes opératoires SAP FI/CO édité par YAASAP, publié avec GitHub Pages : <https://yaasap.github.io/SAP-FICO-EXPERT/>.

## Contenu

- `index.html` : page d'accueil.
- Pages à la racine : atlas (`atlas_*.html`), `formations.html`, fiches (`yaasap_*.html` et autres).
- `sitemap-formations.xml` : plan du site pour les moteurs de recherche.
- `og-*.png`, `yaasap-logo.jpg` : visuels de partage et logo.
- `_archive/` : anciennes versions de pages et de plans du site, conservées sans être publiées (le dossier commence par un tiret bas, Jekyll l'ignore).

## Accès aux fiches payantes

Un seul mécanisme, sans serveur : un code d'accès chiffré, enregistré sur l'appareil du lecteur.

- `acces.html` : saisie du code et liste des fiches débloquées.
- `site.js` : navigation commune et ouverture des fiches chiffrées avec le code local.
- `catalogue.html` : liste des fiches, lue par `site.js`.
- `_archive/acces-email/` : ancien parcours par e-mail (`access.js`, `config.js`, `abonnement.html`, `lire.html`), jamais branché car il dépendait d'un service d'accès non versionné. Conservé pour mémoire, non publié.

## Règles

- Ne jamais committer de clé secrète (Stripe, API, jetons) dans ce dépôt public.
- Les anciennes versions vont dans `_archive/`, pas à la racine, et pas avec un suffixe du type « (1) ».
