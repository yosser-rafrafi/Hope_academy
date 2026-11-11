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

    // Update lastLoginAt — ignore permission errors (can happen if Firestore
    // rules are not yet propagated or during first-time setup).
    try {
      await _db.collection('users').doc(user.uid).set(
        {'lastLoginAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Non-fatal — proceed with login even if timestamp update fails
    }

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

  // ─── Re-authenticate (required before sensitive operations) ─────────────────

  /// Re-authenticates the current user with their password.
  /// Must be called before [updateEmail] or account deletion.
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  // ─── Update email ─────────────────────────────────────────────────────────

  /// Sends a verification to [newEmail]. Firebase will only update the address
  /// after the user clicks the link in that email.
  /// Requires prior call to [reauthenticate].
  Future<void> updateEmail(String newEmail) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    // verifyBeforeUpdateEmail sends a verification link to the new address
    await user.verifyBeforeUpdateEmail(newEmail.trim());
    // Also update the email in Firestore immediately (pre-verified copy)
    await _db.collection('users').doc(user.uid).update({
      'email': newEmail.trim(),
    });
  }

  // ─── Change password ──────────────────────────────────────────────────────

  /// Changes the password directly. Requires prior [reauthenticate] call.
  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) throw FirebaseAuthException(code: 'no-current-user');
    await user.updatePassword(newPassword);
  }

  // ─── Phone sign-in ────────────────────────────────────────────────────────

  /// Step 1 — send OTP to [phoneNumber] (E.164 format e.g. +21612345678).
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(PhoneAuthCredential) onAutoVerified,
    required void Function(FirebaseAuthException) onFailed,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(String verificationId) onTimeout,
    int? resendToken,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onAutoVerified,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onTimeout,
      forceResendingToken: resendToken,
    );
  }

  /// Step 2 — sign in with the OTP the user typed.
  /// Returns the [UserModel] if a Firestore profile exists, null otherwise.
  Future<UserModel?> signInWithOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user == null) return null;

    try {
      await _db.collection('users').doc(user.uid).set(
        {'lastLoginAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}

    return _fetchUserModel(user.uid);
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
