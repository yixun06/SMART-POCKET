import 'package:flutter/material.dart';
import '../auth_guard_state.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/local_storage_service.dart';

class AuthFlowResult {
  final bool success;
  final bool needsSurvey;
  final String? errorMessage;

  const AuthFlowResult({
    required this.success,
    this.needsSurvey = false,
    this.errorMessage,
  });
}

class AuthenticationController extends ChangeNotifier {
  final AuthService _authService;
  final LocalStorageService _localStorage;

  AuthenticationController(this._authService, this._localStorage);

  bool isLoading = false;
  String? errorMessage;

  String? get currentUserId => _authService.currentUserId;
  bool get isLoggedIn => currentUserId != null;

  Future<bool> isSurveyCompleted(String uid) {
    return _authService.isSurveyCompleted(uid);
  }

  Future<bool> isBiometricEnabledFor(String uid) {
    return _authService.isBiometricEnabled(uid);
  }

  Future<AuthFlowResult> signInWithEmail(String email, String password) async {
    _start();
    try {
      final cred = await _authService.signInWithEmail(email, password);
      await _authService.ensureUserDocument(user: cred.user!);
      final needsSurvey = !(await _authService.isSurveyCompleted(
        cred.user!.uid,
      ));

      final mode = await _authService.getUserMode(cred.user!.uid);
      if (mode != null) {
        await _localStorage.saveAppMode(mode);
      }
      AuthGuardState.setUnlocked(true);
      _stop();
      return AuthFlowResult(success: true, needsSurvey: needsSurvey);
    } catch (e) {
      final msg = _authService.mapAuthError(e);
      _fail(msg);
      return AuthFlowResult(success: false, errorMessage: msg);
    }
  }

  Future<AuthFlowResult> registerWithEmail(
    String email,
    String password,
  ) async {
    if (!_isStrongPassword(password)) {
      final msg =
          'Weak password. Use at least 8 chars with letters and numbers.';
      _fail(msg);
      return const AuthFlowResult(
        success: false,
        errorMessage:
            'Weak password. Use at least 8 chars with letters and numbers.',
      );
    }
    _start();
    try {
      final cred = await _authService.registerWithEmail(email, password);
      await _authService.ensureUserDocument(
        user: cred.user!,
        defaultMode: 'lazy',
      );
      await _localStorage.saveAppMode('lazy');
      AuthGuardState.setUnlocked(true);
      _stop();
      return const AuthFlowResult(success: true, needsSurvey: true);
    } catch (e) {
      final msg = _authService.mapAuthError(e);
      _fail(msg);
      return AuthFlowResult(success: false, errorMessage: msg);
    }
  }

  Future<AuthFlowResult> signInWithGoogle() async {
    _start();
    try {
      final cred = await _authService.signInWithGoogle();
      await _authService.ensureUserDocument(user: cred.user!);
      final needsSurvey = !(await _authService.isSurveyCompleted(
        cred.user!.uid,
      ));

      final mode = await _authService.getUserMode(cred.user!.uid);
      if (mode != null) {
        await _localStorage.saveAppMode(mode);
      }
      AuthGuardState.setUnlocked(true);
      _stop();
      return AuthFlowResult(success: true, needsSurvey: needsSurvey);
    } catch (e) {
      final msg = _authService.mapAuthError(e);
      _fail(msg);
      return AuthFlowResult(success: false, errorMessage: msg);
    }
  }

  Future<AuthFlowResult> signInWithBiometric() async {
    _start();
    AuthGuardState.setBiometricPromptInProgress(true);
    try {
      final ok = await _authService.tryBiometricUnlock();
      if (!ok) {
        _fail('Biometric authentication failed.');
        return const AuthFlowResult(
          success: false,
          errorMessage: 'Biometric authentication failed.',
        );
      }
      final uid = _authService.currentUserId;
      if (uid == null) {
        _fail('Please login with email or Google first.');
        return const AuthFlowResult(
          success: false,
          errorMessage: 'Please login with email or Google first.',
        );
      }
      final needsSurvey = !(await _authService.isSurveyCompleted(uid));
      final mode = await _authService.getUserMode(uid);
      if (mode != null) {
        await _localStorage.saveAppMode(mode);
      }
      AuthGuardState.setUnlocked(true);
      _stop();
      return AuthFlowResult(success: true, needsSurvey: needsSurvey);
    } catch (e) {
      final msg = _authService.mapAuthError(e);
      _fail(msg);
      return AuthFlowResult(success: false, errorMessage: msg);
    } finally {
      AuthGuardState.setBiometricPromptInProgress(false);
    }
  }

  Future<bool> sendResetEmail(String email) async {
    _start();
    try {
      await _authService.sendPasswordReset(email);
      _stop();
      return true;
    } catch (e) {
      _fail(_authService.mapAuthError(e));
      return false;
    }
  }

  Future<void> completeSurvey({required int score}) async {
    final uid = _authService.currentUserId;
    if (uid == null) return;
    await _authService.completeSurvey(uid, score: score);
  }

  Future<bool> isBiometricEnabled() async {
    final uid = _authService.currentUserId;
    if (uid == null) return _localStorage.readBiometricEnabled();
    final enabled = await _authService.isBiometricEnabled(uid);
    await _localStorage.saveBiometricEnabled(enabled);
    return enabled;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final uid = _authService.currentUserId;
    if (uid == null) return;
    await _authService.setBiometricEnabled(uid, enabled);
    await _localStorage.saveBiometricEnabled(enabled);
  }

  Future<bool> shouldAutoTriggerBiometric() async {
    final uid = _authService.currentUserId;
    if (uid == null) return false;
    return _authService.isBiometricEnabled(uid);
  }

  Future<bool> changeEmail({
    required String newEmail,
    required String currentPassword,
  }) async {
    _start();
    try {
      await _authService.changeEmail(
        newEmail: newEmail.trim(),
        currentPassword: currentPassword,
      );
      _stop();
      return true;
    } catch (e) {
      _fail(_authService.mapAuthError(e));
      return false;
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!_isStrongPassword(newPassword)) {
      const msg =
          'Weak password. Use at least 8 chars with letters and numbers.';
      _fail(msg);
      return false;
    }
    _start();
    try {
      await _authService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      _stop();
      return true;
    } catch (e) {
      _fail(_authService.mapAuthError(e));
      return false;
    }
  }

  Future<bool> updateDisplayName(String displayName) async {
    _start();
    try {
      await _authService.updateDisplayName(displayName);
      _stop();
      return true;
    } catch (e) {
      _fail(_authService.mapAuthError(e));
      return false;
    }
  }

  Future<bool> logout() async {
    _start();
    try {
      await _authService.signOut();
      await _localStorage.clearAll();
      AuthGuardState.setUnlocked(false);
      _stop();
      return true;
    } catch (e) {
      _fail('Logout failed. Please try again.');
      return false;
    }
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  void _start() {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
  }

  void _stop() {
    isLoading = false;
    errorMessage = null;
    notifyListeners();
  }

  void _fail(String msg) {
    isLoading = false;
    errorMessage = msg;
    notifyListeners();
  }

  bool _isStrongPassword(String value) {
    if (value.length < 8) return false;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    return hasLetter && hasDigit;
  }
}
