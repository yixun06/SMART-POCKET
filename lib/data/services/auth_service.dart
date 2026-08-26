import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart' as g;
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import '../../core/utils/constants.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final g.GoogleSignIn _googleSignIn = g.GoogleSignIn();
  final LocalAuthentication _localAuth = LocalAuthentication();

  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;
  String? get currentUserEmail => _auth.currentUser?.email;
  String? get currentUserDisplayName => _auth.currentUser?.displayName;

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      final g.GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        throw FirebaseAuthException(
          code: 'google-cancelled',
          message: 'Cancelled',
        );
      }

      final g.GoogleSignInAuthentication auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );
      return _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e, stackTrace) {
      _logGoogleSignInFailure(
        source: 'FirebaseAuth',
        code: e.code,
        message: e.message,
        stackTrace: stackTrace,
      );
      rethrow;
    } on PlatformException catch (e, stackTrace) {
      _logGoogleSignInFailure(
        source: 'GoogleSignIn',
        code: e.code,
        message: e.message,
        stackTrace: stackTrace,
      );
      rethrow;
    } catch (e, stackTrace) {
      _logGoogleSignInFailure(
        source: 'Unexpected',
        code: e.runtimeType.toString(),
        message: e.toString(),
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  void _logGoogleSignInFailure({
    required String source,
    required String code,
    required String? message,
    required StackTrace stackTrace,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      'Google sign-in failure [$source/$code]: ${message ?? 'No message'}',
    );
    debugPrintStack(
      label: 'Google sign-in stack trace',
      stackTrace: stackTrace,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }

  Future<void> reauthenticateWithPassword({
    required String currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User not logged in',
      );
    }
    final email = user.email;
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Current account has no email',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User not logged in',
      );
    }
    await reauthenticateWithPassword(currentPassword: currentPassword);
    await user.verifyBeforeUpdateEmail(newEmail);
    await _firestore.collection(AppCollections.users).doc(user.uid).set({
      UserFields.email: newEmail,
      UserFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User not logged in',
      );
    }
    await reauthenticateWithPassword(currentPassword: currentPassword);
    await user.updatePassword(newPassword);
    await _firestore.collection(AppCollections.users).doc(user.uid).set({
      UserFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'User not logged in',
      );
    }
    final name = displayName.trim();
    if (name.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-display-name',
        message: 'Display name cannot be empty',
      );
    }
    await user.updateDisplayName(name);
    await user.reload();
    await _firestore.collection(AppCollections.users).doc(user.uid).set({
      UserFields.displayName: name,
      UserFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> tryBiometricUnlock() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Please login with email or Google first.',
      );
    }

    final supported = await _localAuth.isDeviceSupported();
    final canCheck = await _localAuth.canCheckBiometrics;
    if (!supported || !canCheck) {
      throw FirebaseAuthException(
        code: 'biometric-unavailable',
        message: 'Biometric authentication is not available on this device.',
      );
    }

    try {
      return await _authenticateWithLocalAuth(biometricOnly: true);
    } on PlatformException catch (e) {
      if (e.code == auth_error.biometricOnlyNotSupported) {
        return _authenticateWithLocalAuth(biometricOnly: false);
      }
      throw _mapBiometricException(e);
    }
  }

  Future<bool> _authenticateWithLocalAuth({required bool biometricOnly}) {
    return _localAuth.authenticate(
      localizedReason: 'Authenticate to access Smart Pocket',
      options: AuthenticationOptions(
        biometricOnly: biometricOnly,
        stickyAuth: true,
        useErrorDialogs: true,
      ),
    );
  }

  FirebaseAuthException _mapBiometricException(PlatformException e) {
    switch (e.code) {
      case auth_error.notAvailable:
        return FirebaseAuthException(
          code: 'biometric-unavailable',
          message: 'Biometric authentication is not available on this device.',
        );
      case auth_error.notEnrolled:
        return FirebaseAuthException(
          code: 'biometric-not-enrolled',
          message: 'No fingerprint or face ID is enrolled on this device.',
        );
      case auth_error.lockedOut:
        return FirebaseAuthException(
          code: 'biometric-locked-out',
          message:
              'Biometric is temporarily locked. Unlock the device and try again.',
        );
      case auth_error.permanentlyLockedOut:
        return FirebaseAuthException(
          code: 'biometric-permanently-locked-out',
          message:
              'Biometric is locked. Unlock the device with PIN, pattern, or password first.',
        );
      case 'auth_in_progress':
        return FirebaseAuthException(
          code: 'biometric-auth-in-progress',
          message: 'Biometric authentication is already in progress.',
        );
      default:
        return FirebaseAuthException(
          code: 'biometric-failed',
          message: e.message ?? 'Biometric authentication failed.',
        );
    }
  }

  Future<void> ensureUserDocument({
    required User user,
    String defaultMode = 'lazy',
  }) async {
    final ref = _firestore.collection(AppCollections.users).doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      final now = DateTime.now();
      final model = UserModel(
        id: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'User',
        createdAt: now,
        updatedAt: now,
        appMode: defaultMode,
        isBiometricEnabled: false,
      );
      await ref.set(model.toMap());
    } else {
      await ref.set({
        UserFields.updatedAt: FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<bool> isSurveyCompleted(String uid) async {
    final snap = await _firestore
        .collection(AppCollections.users)
        .doc(uid)
        .get();
    if (!snap.exists) return false;
    final data = snap.data() ?? {};
    final onboarding =
        (data[UserFields.onboarding] as Map<String, dynamic>?) ?? {};
    return onboarding[OnboardingFields.surveyCompleted] == true;
  }

  Future<void> completeSurvey(String uid, {required int score}) async {
    await _firestore.collection(AppCollections.users).doc(uid).set({
      UserFields.onboarding: {
        OnboardingFields.surveyCompleted: true,
        OnboardingFields.surveyScore: score,
      },
      UserFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> getUserMode(String uid) async {
    final snap = await _firestore
        .collection(AppCollections.users)
        .doc(uid)
        .get();
    if (!snap.exists) return null;
    final data = snap.data() ?? {};
    final settings = data[UserFields.settings] as Map<String, dynamic>? ?? {};
    return settings[UserSettingsFields.appMode] as String?;
  }

  Future<Map<String, dynamic>> getUserSettings(String uid) async {
    final snap = await _firestore
        .collection(AppCollections.users)
        .doc(uid)
        .get();
    if (!snap.exists) return const {};
    final data = snap.data() ?? {};
    return (data[UserFields.settings] as Map<String, dynamic>?) ?? {};
  }

  Stream<Map<String, dynamic>> watchUserSettings(String uid) {
    return _firestore.collection(AppCollections.users).doc(uid).snapshots().map(
      (snap) {
        final data = snap.data() ?? {};
        return (data[UserFields.settings] as Map<String, dynamic>?) ?? {};
      },
    );
  }

  Future<void> updateUserMode(String uid, String mode, {String? origin}) async {
    final settings = <String, dynamic>{UserSettingsFields.appMode: mode};
    if (origin != null && origin.isNotEmpty) {
      settings[UserSettingsFields.appModeOrigin] = origin;
    }
    await _firestore.collection(AppCollections.users).doc(uid).set({
      UserFields.settings: settings,
      UserFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> isBiometricEnabled(String uid) async {
    final snap = await _firestore
        .collection(AppCollections.users)
        .doc(uid)
        .get();
    if (!snap.exists) return false;
    final data = snap.data() ?? {};
    final settings = data[UserFields.settings] as Map<String, dynamic>? ?? {};
    return settings[UserSettingsFields.isBiometricEnabled] == true;
  }

  Future<void> setBiometricEnabled(String uid, bool enabled) async {
    await _firestore.collection(AppCollections.users).doc(uid).set({
      UserFields.settings: {UserSettingsFields.isBiometricEnabled: enabled},
      UserFields.updatedAt: FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String mapAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'invalid-email':
        case 'user-disabled':
          return 'Invalid credentials. Please check email/password.';
        case 'user-not-found':
          return 'Email is not registered.';
        case 'google-cancelled':
        case 'account-exists-with-different-credential':
          return 'Google authentication failed. Please try again.';
        case 'weak-password':
          return 'Weak password. Use at least 8 chars with letters and numbers.';
        case 'email-already-in-use':
          return 'This email is already in use.';
        case 'requires-recent-login':
          return 'For security, please login again and retry.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait and try again.';
        case 'invalid-display-name':
          return 'Display name cannot be empty.';
        case 'biometric-unavailable':
        case 'biometric-disabled':
        case 'biometric-not-enrolled':
        case 'biometric-locked-out':
        case 'biometric-permanently-locked-out':
        case 'biometric-auth-in-progress':
          return e.message ?? 'Biometric authentication is unavailable.';
        default:
          return e.message ?? 'Authentication failed.';
      }
    }
    if (e is PlatformException) {
      switch (e.code) {
        case 'NotAvailable':
          return 'Biometric authentication is not available on this device.';
        case 'NotEnrolled':
          return 'No fingerprint or face ID is enrolled on this device.';
        case 'LockedOut':
          return 'Biometric is temporarily locked. Unlock the device and try again.';
        case 'PermanentlyLockedOut':
          return 'Biometric is locked. Unlock with device PIN or password.';
        default:
          return e.message ?? 'Authentication failed.';
      }
    }
    return e.toString();
  }
}
