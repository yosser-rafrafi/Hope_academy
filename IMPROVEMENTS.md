# Hope Academy — lot d'améliorations (v2)

Aucune nouvelle dépendance : tout repose sur des paquets déjà utilisés
(`cloud_firestore`, `firebase_auth`, `http`, `provider`).
⚠️ Je n'ai pas pu compiler le code (pas de SDK Flutter ici) : lancez
`flutter analyze` puis `flutter test` avant de déployer.

## Nouveautés

### 1. Jardin des progrès (parent)
- `services/progress_service.dart` : calcul pur (testable) à partir des activités
  déjà saisies. 6 domaines : Communication, Autonomie, Mouvement & sens, Amitié,
  Créativité, Découverte.
- `widgets/progress_garden.dart` : une plante par domaine (graine → germe → bourgeon
  → fleur → épanouie), série de jours, « moments de fierté ».
- Principe éthique : la croissance est **cumulative et ne diminue jamais**, aucune
  comparaison à une norme, aucune régression affichée.
- Branché dans l'accueil du `ParentDashboard`.

### 2. Mode enfant
- `screens/child/child_mode_screen.dart` : plein écran, très grandes zones tactiles.
  - **Comment je me sens ?** 5 visages ; enregistre un check-in (`mood_checkins`) ;
    propose le coin calme si l'enfant est en difficulté.
  - **Ma journée** : emploi du temps visuel Maintenant / Ensuite / Plus tard.
  - **Coin calme** : respiration guidée + minuteur visuel 1/3/5 min. Respecte le
    réglage système « réduire les animations ».
- Sortie réservée aux adultes : appui long sur le cadenas + petite addition.
- `services/mood_checkin_service.dart` : écriture « au mieux », n'affiche jamais
  d'erreur à l'enfant.

### 3. Rapports IA branchables
- `config/ai_config.dart` + `AiReportService` : si `AI_REPORT_ENDPOINT` est défini,
  le rapport est généré par une Cloud Function (`functions_example/`), sinon
  l'ancien modèle de texte sert de secours (aucune régression).
- Confidentialité : seuls le **prénom** et le contenu des activités destiné aux
  parents sont envoyés. Jamais de diagnostic ni de données médicales.
- Le prompt impose un ton bienveillant, sans comparaison ni vocabulaire de « retard ».

### 4. Robustesse
- `absence_service.dart` : identifiant déterministe `studentId_yyyyMMdd` + transaction
  → plus de doublons si deux enseignants enregistrent en même temps.
- `main.dart` : journalisation centrale des erreurs (prêt pour Crashlytics),
  message convivial en production, cache hors ligne Firestore (100 Mo) sur mobile.

### 5. Tests
- `test/progress_service_test.dart` (8 tests). Remplacez `hope_academy` dans
  l'import par le `name:` de votre `pubspec.yaml`.

## À faire pour activer

1. Ajouter les règles de `firestore.rules.additions` (collection `mood_checkins`).
2. (Optionnel) Déployer `functions_example/` puis lancer l'app avec
   `--dart-define=AI_REPORT_ENDPOINT=<url de la fonction>`.

## Suite recommandée
Rapport par la voix (nécessite `speech_to_text`), consentement droit à l'image,
notifications push (FCM), localisation arabe RTL, PEI (objectifs individuels).
