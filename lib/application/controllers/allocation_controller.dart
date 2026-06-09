import 'package:flutter/foundation.dart';

import '../../core/utils/constants.dart';
import '../../core/models/account_tag_suggestion.dart';
import '../../data/services/allocation_service.dart';
import '../../data/services/auth_service.dart';

class AllocationController extends ChangeNotifier {
  AllocationController(this._service, this._authService);

  final AssetAllocationService _service;
  final AuthService _authService;

  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;

  String? get uid => _authService.currentUserId;

  Future<Map<String, dynamic>> loadGoals() async {
    final userId = _requireUid();
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await _service.loadGoals(userId);
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveGoals({
    required bool enabled,
    required double tolerance,
    required double dailyUse,
    required double savings,
    required double investment,
  }) async {
    final total = dailyUse + savings + investment;
    if ((total - 100).abs() >= 0.0001) {
      throw Exception('Allocation percentages must total 100%');
    }

    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _service.saveGoals(_requireUid(), {
        AllocationFields.enabled: enabled,
        AllocationFields.tolerance: tolerance,
        AllocationFields.targets: {
          AllocationFields.dailyUse: dailyUse,
          AllocationFields.savings: savings,
          AllocationFields.investment: investment,
        },
      });
    } catch (e) {
      errorMessage = e.toString();
      rethrow;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<List<AccountTagSuggestion>> suggestTags() {
    return _service.suggestAccountTags(_requireUid());
  }

  Future<void> applyTags(List<AccountTagSuggestion> suggestions) {
    return _service.applyAccountTagSuggestions(_requireUid(), suggestions);
  }

  Stream<Map<String, double>> watchActualAllocation() {
    final userId = uid;
    if (userId == null) {
      return Stream.value(const {
        AllocationFields.dailyUse: 0,
        AllocationFields.savings: 0,
        AllocationFields.investment: 0,
        '_hasData': 0,
      });
    }
    return _service.watchActualAllocation(userId);
  }

  String _requireUid() {
    final userId = uid;
    if (userId == null) throw Exception('Please login first');
    return userId;
  }
}
