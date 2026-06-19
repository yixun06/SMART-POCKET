import 'package:flutter/foundation.dart';
import '../../core/models/category_model.dart';
import '../../data/services/category_service.dart';

class CategoryController extends ChangeNotifier {
  final CategoryService _service;
  CategoryController(this._service);

  static const List<CategorySeed> _defaultCategories = [
    CategorySeed(name: 'Food', type: 'expense', icon: 'food'),
    CategorySeed(name: 'Transport', type: 'expense', icon: 'transport'),
    CategorySeed(name: 'Shopping', type: 'expense', icon: 'shopping'),
    CategorySeed(name: 'Bills', type: 'expense', icon: 'bill'),
    CategorySeed(name: 'Health', type: 'expense', icon: 'health'),
    CategorySeed(name: 'Education', type: 'expense', icon: 'education'),
    CategorySeed(name: 'Home', type: 'expense', icon: 'home'),
    CategorySeed(name: 'Salary', type: 'income', icon: 'salary'),
    CategorySeed(name: 'Investment', type: 'income', icon: 'trending_up'),
    CategorySeed(name: 'Business', type: 'income', icon: 'business'),
  ];

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
    categories = [];
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _service.ensureDefaultCategories(_defaultCategories);
      categories = await _service.getAllCategories();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureDefaultCategories() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _service.ensureDefaultCategories(_defaultCategories);
      categories = await _service.getAllCategories();
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      isLoading = false;
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

    await _service.addCategory(name: name.trim(), type: type, icon: icon);
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
