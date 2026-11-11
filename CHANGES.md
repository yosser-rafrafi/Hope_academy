# Hope Academy – modifications

## 1. pubspec.yaml (à ajouter)
```yaml
dependencies:
  pdf: ^3.11.0
  printing: ^5.13.0
  share_plus: ^10.1.0
  video_player: ^2.9.0
```
Puis `flutter pub get` et `flutter analyze`.

## 2. Firebase Storage rules
Autoriser l'écriture (utilisateur connecté) sur : `activity_media/**`, `announcement_media/**`, `profile_photos/**`.

## 3. Données Firestore (rétro-compatible, aucun script de migration)
- announcements : `mediaUrls` (liste), `targetRole` = all | student | staff | teacher (filtre maintenant appliqué)
- announcements/{id}/comments : `visibility` = everyone | staff
- activities : `mediaUrls` désormais rempli à la création

## 4. Thème
Utiliser `context.textPrimary / textSecondary / cardBg / pageBg / softFill / divider / brand`
(définis dans core/app_colors.dart) au lieu de `AppColors.textPrimary`, `Colors.white`, etc.

## 5. Fichiers
- MOD models/announcement_model.dart
- MOD models/comment_model.dart
- MOD screens/admin/absence_management_screen.dart
- MOD screens/admin/admin_activities_screen.dart
- MOD screens/admin/admin_dashboard.dart
- MOD screens/admin/class_detail_screen.dart
- MOD screens/admin/class_management_screen.dart
- MOD screens/admin/create_user_screen.dart
- MOD screens/admin/group_activities_screen.dart
- MOD screens/admin/group_activity_details_screen.dart
- MOD screens/admin/student_absences_screen.dart
- MOD screens/admin/student_activities_screen.dart
- MOD screens/admin/user_details_screen.dart
- MOD screens/admin/user_management_screen.dart
- MOD screens/auth/forgot_password_screen.dart
- MOD screens/auth/login_screen.dart
- MOD screens/parent/parent_dashboard.dart
- MOD screens/profile/profile_screen.dart
- MOD screens/shared/student_detail_absence_screen.dart
- MOD screens/teacher/activity_detail_screen.dart
- MOD screens/teacher/create_activity_screen.dart
- MOD screens/teacher/my_activities_screen.dart
- MOD screens/teacher/my_students_screen.dart
- MOD screens/teacher/teacher_dashboard.dart
- MOD services/activity_service.dart
- MOD services/announcement_service.dart
- MOD services/interaction_service.dart
- MOD services/storage_service.dart
- MOD widgets/ai_report_export_dialog.dart
- MOD widgets/announcements_feed_widget.dart
- MOD widgets/comment_thread_widget.dart
- MOD widgets/interaction_bar_widget.dart
- MOD widgets/profile_photo_picker.dart
- MOD widgets/reaction_picker_widget.dart
- MOD widgets/student_avatar.dart
- NEW/screens/shared: portfolio_screen.dart
- NEW/services: portfolio_service.dart
- NEW/services: report_service.dart
- NEW/services: share_service.dart
- NEW/widgets: announcement_composer.dart
- NEW/widgets: announcement_share_sheet.dart
- NEW/widgets: export_sheet.dart
- NEW/widgets: kid_ui.dart
- NEW/widgets: media_widgets.dart
