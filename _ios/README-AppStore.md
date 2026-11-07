# FICO EXPERT — Kit App Store et projet Xcode

## 1. Prérequis (à préparer)

| Élément | Valeur proposée |
|---|---|
| Nom de l'app | FICO EXPERT (30 caractères max) |
| Sous-titre | Fiches et atlas SAP FI/CO |
| Bundle ID | `com.yaasap.sapfico` |
| SKU | `ficoexpert-ios-1` |
| Langue principale | Français |
| Catégorie | Business (secondaire : Education) |
| Éditeur | YAASAP (SASU) |
| Classification d'âge | 4+ (aucun contenu sensible) |
| Prix | Gratuit (voir point d'attention paiement) |
| URL de support | https://yaasap.github.io/SAP-FICO-EXPERT/ |
| URL confidentialité | page `/confidentialite` de l'app Replit publiée |

**Description (FR)**
FICO EXPERT réunit les fiches, atlas et modes opératoires SAP FI/CO édités par YAASAP : comptabilité générale, fournisseurs, clients, immobilisations, CO, banque, taxes et reporting. Recherchez une transaction ou un paramétrage, filtrez par module et consultez les fiches même hors ligne. Les fiches premium se débloquent avec un code d'accès enregistré uniquement sur votre appareil.

**Mots-clés (100 car. max)**
`SAP,FICO,FI,CO,comptabilité,S/4HANA,consultant,finance,transaction,paramétrage`

**Texte promotionnel**
Fiches SAP FI/CO claires, classées par module et consultables hors ligne.

**Captures d'écran** : iPhone 6,9" (1320×2868) et 6,5" ; iPad 13" si l'app est universelle. Pages conseillées : Accueil, Catalogue avec recherche, une fiche, Atlas, Accès.

**Confidentialité (App Privacy)** : « Données non collectées » si aucune analytique ni newsletter n'est ajoutée dans l'app. Le code d'accès reste sur l'appareil.

**Chiffrement** : déjà déclaré `ITSAppUsesNonExemptEncryption = NO` dans le projet.

## 2. Points d'attention de validation Apple

- **Achats de contenu numérique** : l'accès payant à des fiches via un code acheté sur Stripe, utilisé dans l'app, risque d'être refusé (règle 3.1.1 des App Review Guidelines, qui impose normalement l'achat intégré pour le contenu numérique débloqué dans l'app). Vérifie la règle en vigueur ; options : achat intégré StoreKit, ou une première version avec contenu gratuit uniquement.
- **Fonctionnalité minimale** (règle 4.2) : une simple page web emballée peut être refusée. Ajoute de la valeur native : mode hors ligne, recherche, partage, favoris, notifications.
- Pas de lien ou bouton d'achat externe visible dans l'app tant que la règle n'est pas clarifiée.

## 3. Étapes dans ton compte Apple Developer (à faire toi-même)

1. **developer.apple.com → Account** : vérifie que l'adhésion est active et note ton **Team ID** (10 caractères, onglet Membership).
2. **Certificates, Identifiers & Profiles → Identifiers → +** : App IDs → App → description « FICO EXPERT », Bundle ID explicite `com.yaasap.sapfico`. Aucune capability nécessaire pour la v1.
3. **appstoreconnect.apple.com → Apps → +** : Nouvelle app, plateforme iOS, nom, langue Français, sélectionne le Bundle ID, SKU.
4. Renseigne la fiche : description, mots-clés, URL support et confidentialité, catégorie, classification d'âge, captures.
5. **Confidentialité de l'app** : réponds aux questions (« Données non collectées »).
6. **Xcode** : ouvre le projet (voir ci-dessous), onglet Signing & Capabilities, coche « Automatically manage signing », choisis ton équipe.
7. **Product → Archive → Distribute App → App Store Connect → Upload**.
8. **TestFlight** : attends le traitement du build, teste sur ton iPhone, puis dans App Store Connect associe le build à la version et clique **Ajouter pour vérification**.

## 4. Projet Xcode

Contenu : `project.yml` (XcodeGen), `FicoExpert/` (SwiftUI + WKWebView, icône 1024 px, couleur d'accent), cible iOS 16+.

**Générer et ouvrir (sur Mac)**
```
brew install xcodegen
cd FicoExpert
# édite project.yml : DEVELOPMENT_TEAM: "TON_TEAM_ID"
xcodegen generate
open FicoExpert.xcodeproj
```

**Sans XcodeGen** : Xcode → File → New → Project → iOS App (SwiftUI, nom FicoExpert, bundle `com.yaasap.sapfico`), supprime les fichiers générés et glisse dans le projet `FicoExpertApp.swift`, `ContentView.swift` et `Assets.xcassets`.

**Avant l'archive**
- Dans `FicoExpertApp.swift`, remplace `startURL` par l'URL publiée de l'app Replit.
- Si l'URL est sur un autre domaine que ceux de `allowedHosts`, ajoute-le.

**Comportement** : plein écran, fond bleu nuit, tirer pour rafraîchir, gestes avant/arrière, écran d'erreur avec bouton Réessayer, liens externes ouverts dans Safari, stockage local conservé (le code d'accès reste sur l'appareil).

## 5. Fonctions natives ajoutées (v1.1 du projet)

- **Barre du bas** : retour, accueil, favori (étoile), liste des favoris, partage de la page, Premium.
- **Favoris** : enregistrés sur l'appareil (UserDefaults), suppression par balayage.
- **Partage** : feuille de partage iOS avec l'URL de la fiche.
- **Achat intégré (StoreKit 2)** : produit non consommable `com.yaasap.sapfico.premium`, bouton Débloquer, Restaurer mes achats, mise à jour automatique des droits.
- **Pont vers le site** : l'app expose `window.FICO_NATIVE = { platform: 'ios', premium: true|false }` et déclenche l'événement `fico-native` quand l'achat change. Le site doit lire cette valeur pour ouvrir les fiches premium ; sans cette modification côté site, l'achat n'a pas d'effet sur le contenu.

**À faire dans App Store Connect** : Monétisation > Achats intégrés > créer un produit *Non consommable* avec l'identifiant `com.yaasap.sapfico.premium`, un prix, un nom et une description en français, une capture de l'écran d'achat, puis le joindre à la version soumise. Pour tester dans Xcode : Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration, avec un fichier StoreKit créé via File > New > StoreKit Configuration File contenant le même identifiant.

**Compte et fiscalité** : pour vendre, il faut signer l'accord *Apps payantes* et renseigner coordonnées bancaires et fiscales dans App Store Connect (Accords, fiscalité et opérations bancaires).

## 6. Envoyer le build sans Mac (GitHub Actions)

Le workflow `.github/workflows/ios-testflight.yml` utilise un Mac fourni par GitHub : il génère le projet, signe automatiquement via l'API Apple et envoie le build dans App Store Connect (TestFlight).

1. **Clé API** : App Store Connect > Utilisateurs et accès > Intégrations > Clés App Store Connect > « + », nom `GitHub CI`, accès **Admin**. Télécharge le fichier `.p8` (une seule fois) et note l'**ID de clé** et l'**ID de l'émetteur** (Issuer ID).
2. **Dépôt GitHub privé** : crée par exemple `YAASAP/FicoExpert-iOS` et envoie-y le contenu du dossier `FicoExpert` du zip (glisser-déposer dans l'interface web, y compris le dossier `.github`).
3. **Secrets** : Settings > Secrets and variables > Actions > New repository secret :
   - `ASC_KEY_ID` : l'ID de clé
   - `ASC_ISSUER_ID` : l'ID de l'émetteur
   - `ASC_KEY_P8` : le contenu complet du fichier `.p8` (ouvre-le avec le Bloc-notes, copie tout, y compris les lignes BEGIN et END)
4. **Lancer** : onglet Actions > « iOS build et envoi TestFlight » > Run workflow.
5. Après quelques minutes de traitement par Apple, le build apparaît dans App Store Connect > TestFlight, puis dans la version 1.0 de l'app.

Le numéro de build augmente tout seul à chaque lancement. Ne commite jamais le fichier `.p8` dans le dépôt.
