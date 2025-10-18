import 'package:flutter/foundation.dart';
import '../services/supabase_service.dart';

/// Authentication state management
class AuthProvider with ChangeNotifier {
  final SupabaseService? _supabase;
  User? _user;
  bool _isLoading = true;
  String? _error;

  AuthProvider(this._supabase) {
    _initialize();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get error => _error;

  /// Initialize auth state
  Future<void> _initialize() async {
    if (_supabase == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // Get current user
      _user = await _supabase.getCurrentUser();

      // Listen to auth state changes
      _supabase.onAuthStateChange().listen((user) {
        _user = user;
        notifyListeners();
      });

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Auth initialization error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    if (_supabase == null) return false;

    try {
      _error = null;
      notifyListeners();

      final response = await _supabase.signIn(email, password);
      _user = response.user;

      notifyListeners();
      return response.user != null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Sign in error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Sign up with email and password
  Future<bool> signUp(String email, String password) async {
    if (_supabase == null) return false;

    try {
      _error = null;
      notifyListeners();

      final response = await _supabase.signUp(email, password);
      _user = response.user;

      notifyListeners();
      return response.user != null;
    } catch (e) {
      _error = e.toString();
      debugPrint('Sign up error: $e');
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (_supabase == null) return;

    try {
      await _supabase.signOut();
      _user = null;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Sign out error: $e');
      notifyListeners();
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    if (_supabase == null) return;

    try {
      _error = null;
      await _supabase.resetPassword(email);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Reset password error: $e');
      notifyListeners();
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
