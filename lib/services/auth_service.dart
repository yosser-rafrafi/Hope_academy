import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Auth state stream ────────────────────────────────────────────────────

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  // ─── Sign In ──────────────────────────────────────────────────────────────

  Future<UserModel?> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) return null;

    // Update lastLoginAt — use set+merge so it works even if the doc
    // doesn't exist yet (e.g. admin created directly in Firebase Console).
    await _db.collection('users').doc(user.uid).set(
      {'lastLoginAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );

    return _fetchUserModel(user.uid);
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ─── Password Reset ───────────────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  // ─── Fetch current UserModel ──────────────────────────────────────────────

  Future<UserModel?> fetchCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _fetchUserModel(user.uid);
  }

  Future<UserModel?> _fetchUserModel(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();

    // No Firestore document — this can happen for the very first admin account
    // created directly in Firebase Console. Surface a clear error instead of
    // silently returning null so the login screen can show it.
    if (!doc.exists) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'user-profile-missing',
        message:
            'No user profile found for this account. '
            'Please ask an administrator to create your profile in the portal.',
      );
    }

    final model = UserModel.fromFirestore(doc);
    if (!model.isActive) {
      await _auth.signOut();
      throw FirebaseAuthException(
        code: 'user-disabled',
        message: 'This account has been deactivated. Please contact the administrator.',
      );
    }
    return model;
  }

  // ─── Create user (admin only) ─────────────────────────────────────────────
  /// Creates a Firebase Auth account + Firestore document without signing out
  /// the currently logged-in admin, using a secondary FirebaseApp instance.
  Future<UserModel> createUserByAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
    UserStatus status = UserStatus.newUser,
    DateTime? birthday,
    String? cin,
    String? nationality,
    Gender? gender,
    String? phoneNumber,
    String? address,
    String? motherName,
    String? motherPhone,
    String? fatherName,
    String? fatherPhone,
    List<String> diagnoses = const [],
    List<String> allergies = const [],
    List<Medication> medications = const [],
    String? speciality,
    String? group,
    List<String> diplomas = const [],
    List<String> languages = const [],
    double? salary,
    String? additionalInfo,
    DateTime? enrollmentDate,
    String? language,
    List<String> linkedStudentIds = const [],
  }) async {
    // Use a secondary FirebaseApp so the admin stays logged in
    final secondaryApp = await Firebase.initializeApp(
      name: 'secondary_${DateTime.now().millisecondsSinceEpoch}',
      options: Firebase.app().options,
    );
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

    try {
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      final now = DateTime.now();

      final userModel = UserModel(
        uid: uid,
        email: email.trim(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        role: role,
        status: status,
        isActive: true,
        birthday: birthday,
        cin: cin?.trim(),
        nationality: nationality?.trim(),
        gender: gender,
        phoneNumber: phoneNumber?.trim(),
        address: address?.trim(),
        motherName: motherName?.trim(),
        motherPhone: motherPhone?.trim(),
        fatherName: fatherName?.trim(),
        fatherPhone: fatherPhone?.trim(),
        diagnoses: diagnoses,
        allergies: allergies,
        medications: medications,
        speciality: speciality?.trim(),
        group: group?.trim(),
        diplomas: diplomas,
        languages: languages,
        salary: salary,
        additionalInfo: additionalInfo?.trim(),
        createdAt: now,
        enrollmentDate: enrollmentDate,
        language: language,
        linkedStudentIds: linkedStudentIds,
      );

      await _db.collection('users').doc(uid).set(userModel.toFirestore());

      return userModel;
    } finally {
      await secondaryAuth.signOut();
      await secondaryApp.delete();
    }
  }

  // ─── Update user ──────────────────────────────────────────────────────────

  Future<void> updateUser(UserModel user) async {
    await _db
        .collection('users')
        .doc(user.uid)
        .set(user.toFirestore(), SetOptions(merge: true));
  }

  // ─── Toggle active status ─────────────────────────────────────────────────

  Future<void> toggleUserActive(String uid, bool isActive) async {
    await _db.collection('users').doc(uid).set(
      {'isActive': isActive},
      SetOptions(merge: true),
    );
  }
}
