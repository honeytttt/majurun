import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the user's distance unit preference (km vs miles).
/// Default is km. All run data is stored in km internally — this only
/// affects display formatting.
class UnitPreferenceService extends ChangeNotifier {
  static const _key = 'unit_pref_use_km';

  bool _useKm = true;
  bool get useKm => _useKm;

  UnitPreferenceService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _useKm = prefs.getBool(_key) ?? true;
    notifyListeners();
  }

  Future<void> setUseKm(bool value) async {
    if (_useKm == value) return;
    _useKm = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  // ─── Formatting helpers ───────────────────────────────────────────────────

  /// Convert stored km value to display unit.
  double toDisplay(double km) => _useKm ? km : km * 0.621371;

  /// Label for the current unit: 'km' or 'mi'.
  String get unitLabel => _useKm ? 'km' : 'mi';

  /// Pace label: 'min/km' or 'min/mi'.
  String get paceLabel => _useKm ? 'min/km' : 'min/mi';

  /// Format a km value as "X.XX km" or "X.XX mi".
  String formatDistance(double km) =>
      '${toDisplay(km).toStringAsFixed(2)} $unitLabel';

  /// Format a km value with N decimal places.
  String formatDistanceN(double km, int decimals) =>
      '${toDisplay(km).toStringAsFixed(decimals)} $unitLabel';

  // ─── Static convenience (for use where ChangeNotifier not available) ─────

  /// One-shot async read of preference — use sparingly.
  static Future<bool> loadUseKm() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? true;
  }
}
