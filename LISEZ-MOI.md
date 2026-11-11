# Hope Academy — mise à jour (étapes 1, 2, 3)

Copiez le dossier `lib/` par-dessus le vôtre (24 fichiers : 9 modifiés, 15 nouveaux).
**Non compilé** (pas de SDK Flutter dans mon environnement) : lancez `flutter analyze`
et envoyez-moi les erreurs éventuelles, je les corrige.

## 1. pubspec.yaml — à ajouter
```yaml
dependencies:
  flutter_localizations:
    sdk: flutter
```
(`pdf`, `printing`, `share_plus`, `shared_preferences`, `provider` sont déjà utilisés par votre code.)

## 2. Règles Firestore — à ajouter
```
match /pei_plans/{planId} {
  allow read: if request.auth != null;   // idéalement: parent lié à l'élève + équipe
  allow create, update: if request.auth != null
      && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin','subAdmin','teacher'];
  allow delete: if request.auth != null
      && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin','subAdmin'];
  match /progress/{entryId} {
    allow read: if request.auth != null;
    allow write: if request.auth != null
      && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role in ['admin','subAdmin','teacher'];
  }
}
```
Aucun index composite requis (requêtes mono-champ, tri côté client).

## Étape 1 — Absences (toute l'académie / par classe / par jour + PDF)
- `AbsenceManagementScreen` : bascule **Par jour / Par classe**, bouton PDF dans l'en-tête.
- Export (PDF, impression, CSV) = exactement ce qui est affiché (période + filtre classe).
  Liste par classe : « 3 absents / 12 élèves » (jour unique) + classes sans absence.
  Liste par jour : colonne classe. PDF dans la langue de l'app.

## Étape 2 — PEI & suivi des progrès
- Collection `pei_plans` (+ sous-collection `progress`). Échelle d'autonomie 0–4.
- Admin : bouton « PEI & progrès » dans la fiche élève ; Enseignant : icône drapeau dans « Mes élèves » ;
  Parent : bouton sous Portfolio (lecture seule, brouillons masqués).
- Objectifs par domaine, observations datées, graphique d'évolution, progression globale,
  date de révision (alerte retard), export/impression PDF.

## Étape 3 — Multi-langue (fr / en / ar, RTL automatique)
- `lib/l10n/` : sans génération de code. `context.tr('clé', args: {...})`.
- Sélecteur : écran de connexion + carte « Langue » dans le profil (sauvegardée sur le compte).
- **Traduit à 100 %** : PEI, absences (écran, export, PDF), sélecteur.
- **Reste à migrer** : le texte en dur des ~70 autres écrans (dashboards, utilisateurs,
  classes, activités, portfolio…). Méthode : ajouter la clé dans les 3 fichiers `strings_*.dart`,
  remplacer le texte par `context.tr(...)`.

## Pas encore commencé (étape 4)
Finance, messagerie, refactorisation (ex. fusionner `absence_reports_screen` — qui duplique
son propre PDF — avec `ReportService`).
