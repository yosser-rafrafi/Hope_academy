# Système de Gestion des Absences

## Vue d'ensemble

Le système de gestion des absences permet d'enregistrer et de suivre les absences des étudiants par jour (et non par activité).

## Règles d'accès

### Qui peut gérer les absences ?

| Rôle | Enregistrer | Modifier | Supprimer | Consulter Stats |
|------|-------------|----------|-----------|-----------------|
| **Admin** | ✅ | ✅ | ✅ | ✅ |
| **SubAdmin** | ✅ | ✅ | ✅ | ✅ |
| **Teacher** | ✅ | ⚠️ (justifications uniquement) | ❌ | ❌ |
| **Student (Parent)** | ❌ | ❌ | ❌ | ❌ |

### Permissions détaillées

- **Teachers** peuvent :
  - Enregistrer les absences quotidiennes
  - Ajouter des justifications aux absences existantes
  - Voir les absences de leurs étudiants

- **Admin et SubAdmin** peuvent :
  - Tout ce que peut faire un Teacher
  - Modifier le type d'absence
  - Supprimer des absences
  - Consulter les statistiques globales
  - Filtrer par période (mois, année)
  - Voir les étudiants les plus absents

## Structure des données

### AbsenceModel

```dart
class AbsenceModel {
  final String id;
  final String studentId;       // UID de l'étudiant
  final String studentName;     // Nom complet
  final DateTime date;          // Date de l'absence (jour uniquement)
  final AbsenceType type;       // Type d'absence
  final String? reason;         // Raison (optionnel)
  final String? justificationUrl; // Justificatif (optionnel)
  final String recordedById;    // UID de qui a enregistré
  final String recordedByName;  // Nom de qui a enregistré
  final String recordedByRole;  // Rôle
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool parentNotified;    // Parents notifiés
}
```

### Types d'absence

| Type | Label | Emoji | Couleur |
|------|-------|-------|---------|
| `excused` | Justifiée | ✅ | Vert (success) |
| `unexcused` | Non justifiée | ❌ | Rouge (error) |
| `sick` | Maladie | 🤒 | Orange (warning) |
| `authorized` | Autorisée | 📝 | Bleu (info) |

## Écrans

### 1. RecordAbsenceScreen (Teacher)
**Chemin**: `lib/screens/teacher/record_absence_screen.dart`

Permet aux enseignants d'enregistrer une nouvelle absence :
- Sélection de la date
- Sélection de l'étudiant (avec recherche)
- Choix du type d'absence
- Raison optionnelle

### 2. AbsenceManagementScreen (Admin/SubAdmin)
**Chemin**: `lib/screens/admin/absence_management_screen.dart`

Deux onglets :
- **Liste** : Voir toutes les absences avec filtres (date, étudiant)
- **Statistiques** : 
  - Total des absences
  - Répartition par type
  - Top 10 des étudiants les plus absents

### 3. StudentAbsencesScreen (Admin/SubAdmin/Teacher)
**Chemin**: `lib/screens/admin/student_absences_screen.dart`

Affiche les absences d'un étudiant spécifique :
- Filtrage par année et mois
- Statistiques personnelles
- Liste chronologique

## Service : AbsenceService

### Méthodes principales

#### Enregistrement
```dart
Future<String> recordAbsence({
  required String studentId,
  required String studentName,
  required DateTime date,
  required AbsenceType type,
  String? reason,
  String? justificationUrl,
  required String recordedById,
  required String recordedByName,
  required UserRole recordedByRole,
})
```

#### Statistiques
```dart
// Compter par mois
Future<int> countAbsencesByMonth({
  required String studentId,
  required int year,
  required int month,
})

// Compter par année
Future<int> countAbsencesByYear({
  required String studentId,
  required int year,
})

// Stats par type
Future<Map<AbsenceType, int>> getAbsenceStatsByType({
  required String studentId,
  DateTime? startDate,
  DateTime? endDate,
})

// Stats globales (Admin/SubAdmin)
Future<Map<String, dynamic>> getGlobalAbsenceStats({
  DateTime? startDate,
  DateTime? endDate,
})
```

#### Streams
```dart
// Toutes les absences
Stream<List<AbsenceModel>> streamAllAbsences()

// Par étudiant
Stream<List<AbsenceModel>> streamAbsencesByStudent(String studentId)

// Par période
Stream<List<AbsenceModel>> streamAbsencesByDateRange({
  required DateTime startDate,
  required DateTime endDate,
  String? studentId,
})
```

## Intégration dans les dashboards

### Teacher Dashboard
- Onglet "Absences" (index 3)
- Bouton "+" pour enregistrer une nouvelle absence
- Navigation vers `RecordAbsenceScreen`

### Admin Dashboard
- Section "Attendance" dans le menu
- Navigation vers `AbsenceManagementScreen`
- Statistiques globales accessibles

## Firestore

### Collection : `absences`

**Structure d'un document** :
```json
{
  "studentId": "abc123",
  "studentName": "Jean Dupont",
  "date": Timestamp(2026-07-08),
  "type": "unexcused",
  "reason": "Absent sans justification",
  "justificationUrl": null,
  "recordedById": "teacher123",
  "recordedByName": "Marie Martin",
  "recordedByRole": "teacher",
  "createdAt": Timestamp,
  "updatedAt": Timestamp,
  "parentNotified": false
}
```

### Index Firestore requis

Pour optimiser les requêtes, créez ces index composites :

1. `absences` : `studentId` (ASC) + `date` (DESC)
2. `absences` : `date` (ASC) + `studentId` (ASC)

Firebase vous proposera automatiquement de créer ces index lors de la première utilisation.

## Évolutions futures

### Phase 2
- [ ] Notifications automatiques aux parents
- [ ] Upload de justificatifs (certificats médicaux)
- [ ] Génération de rapports PDF
- [ ] Alertes automatiques (seuil d'absences dépassé)

### Phase 3
- [ ] Synchronisation avec le calendrier académique
- [ ] Intégration avec le système d'activités
- [ ] Tableau de bord dédié aux parents
- [ ] Export Excel des statistiques

## Notes techniques

- Les dates sont **normalisées** (heure à 00:00:00) pour comparer uniquement le jour
- Une seule absence par étudiant par jour (vérification automatique)
- Les statistiques utilisent des agrégations côté client pour éviter des index complexes
- Les permissions sont vérifiées à la fois dans l'UI et dans le service

## Support

Pour toute question, contactez l'équipe technique de Hope Academy.
