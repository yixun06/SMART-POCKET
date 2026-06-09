import 'package:flutter/foundation.dart';

class AuthGuardRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

class AuthGuardState {
  static bool biometricUnlockedInSession = false;
  static bool biometricPromptInProgress = false;
  static final AuthGuardRefresh routerRefresh = AuthGuardRefresh();

  static void setUnlocked(bool value) {
    biometricUnlockedInSession = value;
    routerRefresh.ping();
  }

  static void setBiometricPromptInProgress(bool value) {
    biometricPromptInProgress = value;
  }
}
