import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shoe Tracking Service - Track mileage per shoe like Nike
/// Helps users know when to replace shoes (typically 500-800km)
class ShoeTrackingService extends ChangeNotifier {
  static final ShoeTrackingService _instance = ShoeTrackingService._internal();
  factory ShoeTrackingService() => _instance;
  ShoeTrackingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  List<Shoe> _shoes = [];
  Shoe? _activeShoe;

  List<Shoe> get shoes => List.unmodifiable(_shoes);
  Shoe? get activeShoe => _activeShoe;

  // Industry standard: shoes last 500-800km
  static const double warningThresholdKm = 500;
  static const double retireThresholdKm = 800;

  void setUserId(String? userId) {
    _userId = userId;
    if (userId != null) {
      _loadShoes();
    }
  }

  Future<void> _loadShoes() async {
    if (_userId == null) return;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('shoes')
          .where('isRetired', isEqualTo: false)
          .orderBy('isDefault', descending: true)
          .get();

      _shoes = snapshot.docs.map((doc) {
        return Shoe.fromMap(doc.data(), doc.id);
      }).toList();

      // Set active shoe to default
      _activeShoe = _shoes.firstWhere(
        (s) => s.isDefault,
        orElse: () => _shoes.isNotEmpty ? _shoes.first : Shoe.empty(),
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading shoes: $e');
    }
  }

  /// Add a new shoe
  Future<Shoe?> addShoe({
    required String name,
    required String brand,
    String? model,
    ShoeType type = ShoeType.running,
    double initialDistanceKm = 0,
    DateTime? purchaseDate,
  }) async {
    if (_userId == null) return null;

    try {
      final isFirst = _shoes.isEmpty;

      final shoeData = {
        'name': name,
        'brand': brand,
        'model': model,
        'type': type.index,
        'totalDistanceKm': initialDistanceKm,
        'runCount': 0,
        'purchaseDate': purchaseDate != null
            ? Timestamp.fromDate(purchaseDate)
            : FieldValue.serverTimestamp(),
        'isDefault': isFirst,
        'isRetired': false,
        'notes': '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      final docRef = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('shoes')
          .add(shoeData);

      final shoe = Shoe.fromMap({
        ...shoeData,
        'purchaseDate': Timestamp.now(),
        'createdAt': Timestamp.now(),
      }, docRef.id);

      _shoes.add(shoe);
      if (isFirst) _activeShoe = shoe;

      notifyListeners();
      return shoe;
    } catch (e) {
      debugPrint('Error adding shoe: $e');
      return null;
    }
  }

  /// Set the active shoe for tracking
  void setActiveShoe(String shoeId) {
    _activeShoe = _shoes.firstWhere(
      (s) => s.id == shoeId,
      orElse: () => _activeShoe ?? Shoe.empty(),
    );
    notifyListeners();
  }

  /// Set a shoe as the default
  Future<void> setDefaultShoe(String shoeId) async {
    if (_userId == null) return;

    try {
      // Remove default from all shoes
      final batch = _firestore.batch();
      for (final shoe in _shoes) {
        if (shoe.isDefault) {
          batch.update(
            _firestore.collection('users').doc(_userId).collection('shoes').doc(shoe.id),
            {'isDefault': false},
          );
        }
      }

      // Set new default
      batch.update(
        _firestore.collection('users').doc(_userId).collection('shoes').doc(shoeId),
        {'isDefault': true},
      );

      await batch.commit();

      // Update local state
      _shoes = _shoes.map((s) {
        if (s.id == shoeId) {
          return Shoe(
            id: s.id,
            name: s.name,
            brand: s.brand,
            model: s.model,
            type: s.type,
            totalDistanceKm: s.totalDistanceKm,
            runCount: s.runCount,
            purchaseDate: s.purchaseDate,
            isDefault: true,
            isRetired: s.isRetired,
            notes: s.notes,
          );
        } else {
          return Shoe(
            id: s.id,
            name: s.name,
            brand: s.brand,
            model: s.model,
            type: s.type,
            totalDistanceKm: s.totalDistanceKm,
            runCount: s.runCount,
            purchaseDate: s.purchaseDate,
            isDefault: false,
            isRetired: s.isRetired,
            notes: s.notes,
          );
        }
      }).toList();

      _activeShoe = _shoes.firstWhere((s) => s.id == shoeId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting default shoe: $e');
    }
  }

  /// Record mileage for a run
  Future<void> recordRun(String shoeId, double distanceKm) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('shoes')
          .doc(shoeId)
          .update({
        'totalDistanceKm': FieldValue.increment(distanceKm),
        'runCount': FieldValue.increment(1),
      });

      // Update local state
      _shoes = _shoes.map((s) {
        if (s.id == shoeId) {
          return Shoe(
            id: s.id,
            name: s.name,
            brand: s.brand,
            model: s.model,
            type: s.type,
            totalDistanceKm: s.totalDistanceKm + distanceKm,
            runCount: s.runCount + 1,
            purchaseDate: s.purchaseDate,
            isDefault: s.isDefault,
            isRetired: s.isRetired,
            notes: s.notes,
          );
        }
        return s;
      }).toList();

      if (_activeShoe?.id == shoeId) {
        _activeShoe = _shoes.firstWhere((s) => s.id == shoeId);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error recording run for shoe: $e');
    }
  }

  /// Retire a shoe
  Future<void> retireShoe(String shoeId) async {
    if (_userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('shoes')
          .doc(shoeId)
          .update({
        'isRetired': true,
        'retiredAt': FieldValue.serverTimestamp(),
      });

      _shoes.removeWhere((s) => s.id == shoeId);

      // If active shoe was retired, set new active
      if (_activeShoe?.id == shoeId) {
        _activeShoe = _shoes.isNotEmpty ? _shoes.first : null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error retiring shoe: $e');
    }
  }

  /// Update shoe details
  Future<void> updateShoe({
    required String shoeId,
    String? name,
    String? notes,
  }) async {
    if (_userId == null) return;

    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (notes != null) updates['notes'] = notes;

      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('shoes')
          .doc(shoeId)
          .update(updates);

      // Update local state
      _shoes = _shoes.map((s) {
        if (s.id == shoeId) {
          return Shoe(
            id: s.id,
            name: name ?? s.name,
            brand: s.brand,
            model: s.model,
            type: s.type,
            totalDistanceKm: s.totalDistanceKm,
            runCount: s.runCount,
            purchaseDate: s.purchaseDate,
            isDefault: s.isDefault,
            isRetired: s.isRetired,
            notes: notes ?? s.notes,
          );
        }
        return s;
      }).toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating shoe: $e');
    }
  }

  /// Get shoes needing attention (high mileage)
  List<ShoeAlert> getShoeAlerts() {
    List<ShoeAlert> alerts = [];

    for (final shoe in _shoes) {
      if (shoe.totalDistanceKm >= retireThresholdKm) {
        alerts.add(ShoeAlert(
          shoe: shoe,
          type: ShoeAlertType.retire,
          message: '${shoe.name} has ${shoe.totalDistanceKm.toStringAsFixed(0)}km - time to retire!',
        ));
      } else if (shoe.totalDistanceKm >= warningThresholdKm) {
        final remaining = retireThresholdKm - shoe.totalDistanceKm;
        alerts.add(ShoeAlert(
          shoe: shoe,
          type: ShoeAlertType.warning,
          message: '${shoe.name} has ${shoe.totalDistanceKm.toStringAsFixed(0)}km - ${remaining.toStringAsFixed(0)}km until retirement',
        ));
      }
    }

    return alerts;
  }

  /// Get retired shoes history
  Future<List<Shoe>> getRetiredShoes() async {
    if (_userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('shoes')
          .where('isRetired', isEqualTo: true)
          .orderBy('retiredAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        return Shoe.fromMap(doc.data(), doc.id);
      }).toList();
    } catch (e) {
      debugPrint('Error loading retired shoes: $e');
      return [];
    }
  }
}

// Data classes

enum ShoeType {
  running,
  trail,
  racing,
  walking,
  other,
}

extension ShoeTypeExtension on ShoeType {
  String get name {
    switch (this) {
      case ShoeType.running:
        return 'Running';
      case ShoeType.trail:
        return 'Trail';
      case ShoeType.racing:
        return 'Racing';
      case ShoeType.walking:
        return 'Walking';
      case ShoeType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case ShoeType.running:
        return Icons.directions_run;
      case ShoeType.trail:
        return Icons.terrain;
      case ShoeType.racing:
        return Icons.speed;
      case ShoeType.walking:
        return Icons.directions_walk;
      case ShoeType.other:
        return Icons.more_horiz;
    }
  }
}

enum ShoeAlertType {
  warning,
  retire,
}

class Shoe {
  final String id;
  final String name;
  final String brand;
  final String? model;
  final ShoeType type;
  final double totalDistanceKm;
  final int runCount;
  final DateTime purchaseDate;
  final bool isDefault;
  final bool isRetired;
  final String notes;

  const Shoe({
    required this.id,
    required this.name,
    required this.brand,
    this.model,
    required this.type,
    required this.totalDistanceKm,
    required this.runCount,
    required this.purchaseDate,
    required this.isDefault,
    required this.isRetired,
    this.notes = '',
  });

  factory Shoe.empty() {
    return Shoe(
      id: '',
      name: 'No Shoe',
      brand: '',
      type: ShoeType.running,
      totalDistanceKm: 0,
      runCount: 0,
      purchaseDate: DateTime.now(),
      isDefault: false,
      isRetired: false,
    );
  }

  factory Shoe.fromMap(Map<String, dynamic> map, String id) {
    return Shoe(
      id: id,
      name: map['name'] as String? ?? 'Unknown',
      brand: map['brand'] as String? ?? '',
      model: map['model'] as String?,
      type: ShoeType.values[map['type'] as int? ?? 0],
      totalDistanceKm: (map['totalDistanceKm'] as num?)?.toDouble() ?? 0,
      runCount: (map['runCount'] as num?)?.toInt() ?? 0,
      purchaseDate: (map['purchaseDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isDefault: map['isDefault'] as bool? ?? false,
      isRetired: map['isRetired'] as bool? ?? false,
      notes: map['notes'] as String? ?? '',
    );
  }

  double get healthPercent {
    final remaining = ShoeTrackingService.retireThresholdKm - totalDistanceKm;
    return (remaining / ShoeTrackingService.retireThresholdKm * 100).clamp(0, 100);
  }

  Color get healthColor {
    if (totalDistanceKm >= ShoeTrackingService.retireThresholdKm) {
      return const Color(0xFFF44336); // Red
    } else if (totalDistanceKm >= ShoeTrackingService.warningThresholdKm) {
      return const Color(0xFFFF9800); // Orange
    }
    return const Color(0xFF4CAF50); // Green
  }

  String get displayName {
    if (model != null && model!.isNotEmpty) {
      return '$brand $model';
    }
    return name;
  }
}

class ShoeAlert {
  final Shoe shoe;
  final ShoeAlertType type;
  final String message;

  const ShoeAlert({
    required this.shoe,
    required this.type,
    required this.message,
  });
}
