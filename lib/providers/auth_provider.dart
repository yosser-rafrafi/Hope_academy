import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.initial;
  UserModel? _currentUser;
  String? _errorMessage;
  String? _errorCode;
  bool _isCreatingUser = false;
  String? _createUserError;

  // ─── Getters ──────────────────────────────────────────────────────────────

  AuthStatus get status => _status;
  UserModel? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;
  bool get isAccountDeactivated => _errorCode == 'user-disabled';
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isLoading => _status == AuthStatus.loading;
  bool get isCreatingUser => _isCreatingUser;
  String? get createUserError => _createUserError;

  // ─── Initialize ───────────────────────────────────────────────────────────

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        _status = AuthStatus.unauthenticated;
        _currentUser = null;
        notifyListeners();
      } else {
        try {
          _currentUser = await _authService.fetchCurrentUser();
          _status = _currentUser != null
              ? AuthStatus.authenticated
              : AuthStatus.unauthenticated;
        } catch (_) {
          _status = AuthStatus.unauthenticated;
          _currentUser = null;
        }
        notifyListeners();
      }
    });
  }

  // ─── Sign In ──────────────────────────────────────────────────────────────

  Future<bool> signIn(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.signIn(email, password);
      if (_currentUser != null) {
        _status = AuthStatus.authenticated;
        _errorCode = null;
        notifyListeners();
        return true;
      } else {
        _status = AuthStatus.unauthenticated;
        _errorCode = null;
        _errorMessage = 'User profile not found. Please contact the administrator.';
        notifyListeners();
        return false;
      }
    } on FirebaseAuthException catch (e) {
      _status = AuthStatus.error;
      _errorCode = e.code;
      _errorMessage = _mapFirebaseError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _status = AuthStatus.error;
      _errorCode = null;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Sign Out ─────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── Password Reset ───────────────────────────────────────────────────────

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapFirebaseError(e);
      notifyListeners();
      return false;
    }
  }

  // ─── Create User (Admin) ──────────────────────────────────────────────────

  Future<UserModel?> createUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required UserRole role,
    String? phoneNumber,
    String? speciality,
    List<String> linkedStudentIds = const [],
  }) async {
    _isCreatingUser = true;
    _createUserError = null;
    notifyListeners();

    try {
      final newUser = await _authService.createUserByAdmin(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: role,
        phoneNumber: phoneNumber,
        speciality: speciality,
        linkedStudentIds: linkedStudentIds,
      );
      _isCreatingUser = false;
      notifyListeners();
      return newUser;
    } on FirebaseAuthException catch (e) {
      _createUserError = _mapFirebaseError(e);
      _isCreatingUser = false;
      notifyListeners();
      return null;
    } catch (e) {
      _createUserError = e.toString();
      _isCreatingUser = false;
      notifyListeners();
      return null;
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  // ─── Refresh current user ─────────────────────────────────────────────────

  Future<void> refreshCurrentUser() async {
    try {
      _currentUser = await _authService.fetchCurrentUser();
      notifyListeners();
    } catch (_) {
      // Silently ignore — user still stays authenticated
    }
  }

  // ─── Update current user's own profile ───────────────────────────────────

  Future<void> updateCurrentUserProfile(UserModel updated) async {
    await _authService.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    _errorCode = null;
    _createUserError = null;
    notifyListeners();
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'user-disabled':
        return e.message ?? 'This account has been deactivated.';
      default:
        return e.message ?? 'An unexpected error occurred. Please try again.';
    }
  }
}
