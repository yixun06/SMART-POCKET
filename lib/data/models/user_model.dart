import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/constants.dart';

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String appMode; // lazy | detailed
  final bool isBiometricEnabled;

  const UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
    required this.appMode,
    required this.isBiometricEnabled,
  });

  Map<String, dynamic> toMap() {
    return {
      UserFields.id: id,
      UserFields.email: email,
      UserFields.displayName: displayName,
      UserFields.createdAt: Timestamp.fromDate(createdAt),
      UserFields.updatedAt: Timestamp.fromDate(updatedAt),
      UserFields.settings: {
        UserSettingsFields.appMode: appMode,
        UserSettingsFields.isBiometricEnabled: isBiometricEnabled,
      },
      UserFields.onboarding: {
        OnboardingFields.surveyCompleted: false,
        OnboardingFields.surveyScore: 0,
      },
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final settings = (map[UserFields.settings] as Map<String, dynamic>? ?? {});
    final createdTs = map[UserFields.createdAt] as Timestamp?;
    final updatedTs = map[UserFields.updatedAt] as Timestamp?;

    return UserModel(
      id: map[UserFields.id] as String? ?? '',
      email: map[UserFields.email] as String? ?? '',
      displayName: map[UserFields.displayName] as String? ?? '',
      createdAt: createdTs?.toDate() ?? DateTime.now(),
      updatedAt: updatedTs?.toDate() ?? DateTime.now(),
      appMode: settings[UserSettingsFields.appMode] as String? ?? 'lazy',
      isBiometricEnabled:
          settings[UserSettingsFields.isBiometricEnabled] as bool? ?? false,
    );
  }
}
