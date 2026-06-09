import 'package:flutter/foundation.dart';
import '../../core/models/category_model.dart';
import '../../data/services/category_service.dart';

class CategoryController extends ChangeNotifier {
  final CategoryService _service;
  CategoryController(this._service);

  bool isLoading = false;
  String? errorMessage;
  List<CategoryModel> categories = [];

  Future<void> bind() async {
    await refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      categories = await _service.getAllCategories();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> handleAuthChanged() async {
    if (categories.isNotEmpty) {
      categories = [];
      notifyListeners();
    }
    await refresh();
  }

  Future<void> ensureDefaultCategories() async {
    try {
      await _service.ensureDefaultCategories([
        const CategorySeed(name: 'Food', type: 'expense', icon: 'food'),
        const CategorySeed(name: 'Transport', type: 'expense', icon: 'transport'),
        const CategorySeed(name: 'Shopping', type: 'expense', icon: 'shopping'),
        const CategorySeed(name: 'Bills', type: 'expense', icon: 'bill'),
        const CategorySeed(name: 'Health', type: 'expense', icon: 'health'),
        const CategorySeed(name: 'Education', type: 'expense', icon: 'education'),
        const CategorySeed(name: 'Home', type: 'expense', icon: 'home'),
        const CategorySeed(name: 'Salary', type: 'income', icon: 'salary'),
        const CategorySeed(name: 'Investment', type: 'income', icon: 'trending_up'),
        const CategorySeed(name: 'Business', type: 'income', icon: 'business'),
      ]);
      await refresh();
    } catch (e) {
      errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> addCategory({
    required String name,
    required String type,
    String? icon,
  }) async {
    if (name.trim().isEmpty) {
      errorMessage = 'Category name required';
      notifyListeners();
      return;
    }

    await _service.addCategory(
      name: name.trim(),
      type: type,
      icon: icon,
    );
    await refresh();
  }

  Future<void> editCategory({
    required String id,
    required String name,
    required String type,
    String? icon,
  }) async {
    if (name.trim().isEmpty) {
      errorMessage = 'Category name required';
      notifyListeners();
      return;
    }

    await _service.updateCategory(
      id: id,
      name: name.trim(),
      type: type,
      icon: icon,
    );
    await refresh();
  }

  Future<void> deleteCategoryAndReassign({
    required String categoryId,
    required String toCategoryId,
  }) async {
    await _service.deleteCategoryAndReassign(
      categoryId: categoryId,
      toCategoryId: toCategoryId,
    );
    await refresh();
  }

  Future<void> deleteCategoryAndDeleteTransactions({
    required String categoryId,
  }) async {
    await _service.deleteCategoryAndDeleteTransactions(categoryId: categoryId);
    await refresh();
  }
}
