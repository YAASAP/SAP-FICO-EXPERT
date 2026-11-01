# SAP FICO EXPERT

Site de fiches, d'atlas et de modes opératoires SAP FI/CO édité par YAASAP, publié avec GitHub Pages : <https://yaasap.github.io/SAP-FICO-EXPERT/>.

## Contenu

- `index.html` : page d'accueil.
- Pages à la racine : atlas (`atlas_*.html`), `formations.html`, fiches (`yaasap_*.html` et autres).
- `sitemap-formations.xml` : plan du site pour les moteurs de recherche.
- `og-*.png`, `yaasap-logo.jpg` : visuels de partage et logo.
- `_archive/` : anciennes versions de pages et de plans du site, conservées sans être publiées (le dossier commence par un tiret bas, Jekyll l'ignore).

## Accès aux fiches payantes

- `acces.html`, `abonnement.html`, `lire.html` : parcours d'accès et d'abonnement.
- `access.js` : client e-mail → code → jeton, paiement Stripe et portail de facturation. Il appelle un service d'accès dont l'adresse est dans `config.js` (`API_BASE`). Le code de ce service n'est pas versionné dans ce dépôt.
- `site.js` : navigation commune et ouverture des fiches chiffrées avec un code local.
- `config.js` : adresse du service d'accès, libellés de prix affichés, e-mail de support.

## Règles

- Ne jamais committer de clé secrète (Stripe, API, jetons) dans ce dépôt public.
- Les anciennes versions vont dans `_archive/`, pas à la racine, et pas avec un suffixe du type « (1) ».
