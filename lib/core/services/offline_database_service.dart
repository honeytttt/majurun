import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Offline database service for storing runs when offline
class OfflineDatabaseService {
  static final OfflineDatabaseService _instance = OfflineDatabaseService._internal();
  factory OfflineDatabaseService() => _instance;
  OfflineDatabaseService._internal();

  Database? _database;
  bool _initialized = false;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      debugPrint('OfflineDatabase: Web platform - using in-memory fallback');
      _initialized = true;
      return;
    }
    await database;
    _initialized = true;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'majurun_offline.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Pending runs table - runs saved offline
    await db.execute('''
      CREATE TABLE pending_runs (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        distance_meters REAL NOT NULL,
        duration_seconds INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT,
        route_points TEXT,
        avg_pace REAL,
        avg_heart_rate INTEGER,
        calories INTEGER,
        elevation_gain REAL,
        weather_data TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0,
        plan_title TEXT,
        pace TEXT
      )
    ''');

    // Cached user data
    await db.execute('''
      CREATE TABLE cached_users (
        id TEXT PRIMARY KEY,
        display_name TEXT,
        photo_url TEXT,
        bio TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    // Pending posts
    await db.execute('''
      CREATE TABLE pending_posts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        content TEXT,
        media_url TEXT,
        run_id TEXT,
        created_at TEXT NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');

    debugPrint('OfflineDatabase: Tables created');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // v1 → v2: add plan_title and pace columns
      await db.execute('ALTER TABLE pending_runs ADD COLUMN plan_title TEXT');
      await db.execute('ALTER TABLE pending_runs ADD COLUMN pace TEXT');
    }
  }

  // ============ Pending Runs ============

  /// Save a run for offline sync
  Future<void> savePendingRun(PendingRun run) async {
    if (kIsWeb) return; // Skip on web

    final db = await database;
    await db.insert(
      'pending_runs',
      run.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    debugPrint('OfflineDatabase: Saved pending run ${run.id}');
  }

  /// Get all pending runs that need to be synced
  Future<List<PendingRun>> getPendingRuns() async {
    if (kIsWeb) return [];

    final db = await database;
    final maps = await db.query(
      'pending_runs',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => PendingRun.fromMap(map)).toList();
  }

  /// Mark a run as synced
  Future<void> markRunSynced(String runId) async {
    if (kIsWeb) return;

    final db = await database;
    await db.update(
      'pending_runs',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [runId],
    );
  }

  /// Returns unsynced pending runs formatted as history map (for merging into UI).
  Future<List<Map<String, dynamic>>> getUnsyncedRunsAsHistory() async {
    if (kIsWeb) return [];
    final runs = await getPendingRuns();
    return runs.where((r) => !r.synced).map((r) {
      final distKm = r.distanceMeters / 1000;
      final pace = r.pace ?? (distKm > 0
          ? '${(r.durationSeconds / distKm / 60).floor()}:${((r.durationSeconds / distKm) % 60).toInt().toString().padLeft(2, '0')}'
          : '--:--');
      return <String, dynamic>{
        'id': '_local_${r.id}',
        'localId': r.id,
        'date': r.startTime,
        'distance': distKm,
        'durationSeconds': r.durationSeconds,
        'pace': pace,
        'calories': r.calories ?? 0,
        'planTitle': r.planTitle ?? 'Free Run',
        'avgBpm': r.avgHeartRate ?? 0,
        'routePoints': null,
        'isPendingSync': true,
        if (r.elevationGain != null) 'elevationGain': r.elevationGain,
      };
    }).toList();
  }

  /// Try to push all unsynced runs to Firestore.
  /// Call this in the background when connectivity is available.
  Future<void> syncPendingRunsToFirestore({
    required Future<void> Function({
      required String planTitle,
      required double distanceKm,
      required int durationSeconds,
      required String pace,
      int? avgBpm,
      int? calories,
      Map<String, dynamic>? extra,
    }) saveRunFn,
  }) async {
    if (kIsWeb) return;
    final runs = await getPendingRuns();
    final unsynced = runs.where((r) => !r.synced).toList();
    for (final run in unsynced) {
      try {
        final distKm = run.distanceMeters / 1000;
        final pace = run.pace ?? (distKm > 0
            ? '${(run.durationSeconds / distKm / 60).floor()}:${((run.durationSeconds / distKm) % 60).toInt().toString().padLeft(2, '0')}'
            : '--:--');
        await saveRunFn(
          planTitle: run.planTitle ?? 'Free Run',
          distanceKm: distKm,
          durationSeconds: run.durationSeconds,
          pace: pace,
          avgBpm: run.avgHeartRate,
          calories: run.calories,
          extra: run.elevationGain != null ? {'elevationGain': run.elevationGain} : null,
        );
        await markRunSynced(run.id);
        debugPrint('✅ Synced offline run ${run.id} to Firestore');
      } catch (e) {
        debugPrint('⚠️ Could not sync run ${run.id}: $e');
      }
    }
  }

  /// Delete synced runs older than 7 days
  Future<void> cleanupSyncedRuns() async {
    if (kIsWeb) return;

    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    await db.delete(
      'pending_runs',
      where: 'synced = ? AND created_at < ?',
      whereArgs: [1, cutoff],
    );
  }

  /// Get count of pending runs
  Future<int> getPendingRunCount() async {
    if (kIsWeb) return 0;

    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM pending_runs WHERE synced = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ============ Cached Users ============

  /// Cache user data for offline access
  Future<void> cacheUser(CachedUser user) async {
    if (kIsWeb) return;

    final db = await database;
    await db.insert(
      'cached_users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get cached user
  Future<CachedUser?> getCachedUser(String userId) async {
    if (kIsWeb) return null;

    final db = await database;
    final maps = await db.query(
      'cached_users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CachedUser.fromMap(maps.first);
  }

  // ============ Pending Posts ============

  /// Save a post for offline sync
  Future<void> savePendingPost(PendingPost post) async {
    if (kIsWeb) return;

    final db = await database;
    await db.insert(
      'pending_posts',
      post.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all pending posts
  Future<List<PendingPost>> getPendingPosts() async {
    if (kIsWeb) return [];

    final db = await database;
    final maps = await db.query(
      'pending_posts',
      where: 'synced = ?',
      whereArgs: [0],
      orderBy: 'created_at ASC',
    );
    return maps.map((map) => PendingPost.fromMap(map)).toList();
  }

  /// Mark a post as synced
  Future<void> markPostSynced(String postId) async {
    if (kIsWeb) return;

    final db = await database;
    await db.update(
      'pending_posts',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [postId],
    );
  }

  /// Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

// ============ Data Models ============

class PendingRun {
  final String id;
  final String userId;
  final double distanceMeters;
  final int durationSeconds;
  final DateTime startTime;
  final DateTime? endTime;
  final List<Map<String, double>>? routePoints;
  final double? avgPace;
  final int? avgHeartRate;
  final int? calories;
  final double? elevationGain;
  final Map<String, dynamic>? weatherData;
  final DateTime createdAt;
  final bool synced;
  final String? planTitle;
  final String? pace;

  PendingRun({
    required this.id,
    required this.userId,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startTime,
    this.endTime,
    this.routePoints,
    this.avgPace,
    this.avgHeartRate,
    this.calories,
    this.elevationGain,
    this.weatherData,
    required this.createdAt,
    this.synced = false,
    this.planTitle,
    this.pace,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'route_points': routePoints != null ? jsonEncode(routePoints) : null,
      'avg_pace': avgPace,
      'avg_heart_rate': avgHeartRate,
      'calories': calories,
      'elevation_gain': elevationGain,
      'weather_data': weatherData != null ? jsonEncode(weatherData) : null,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
      'plan_title': planTitle,
      'pace': pace,
    };
  }

  factory PendingRun.fromMap(Map<String, dynamic> map) {
    return PendingRun(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      distanceMeters: (map['distance_meters'] as num).toDouble(),
      durationSeconds: map['duration_seconds'] as int,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time'] as String) : null,
      routePoints: map['route_points'] != null
          ? (jsonDecode(map['route_points'] as String) as List)
              .map((e) => Map<String, double>.from(e as Map))
              .toList()
          : null,
      avgPace: map['avg_pace'] != null ? (map['avg_pace'] as num).toDouble() : null,
      avgHeartRate: map['avg_heart_rate'] as int?,
      calories: map['calories'] as int?,
      elevationGain: map['elevation_gain'] != null ? (map['elevation_gain'] as num).toDouble() : null,
      weatherData: map['weather_data'] != null
          ? jsonDecode(map['weather_data'] as String) as Map<String, dynamic>
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      synced: map['synced'] == 1,
      planTitle: map['plan_title'] as String?,
      pace: map['pace'] as String?,
    );
  }
}

class CachedUser {
  final String id;
  final String? displayName;
  final String? photoUrl;
  final String? bio;
  final DateTime updatedAt;

  CachedUser({
    required this.id,
    this.displayName,
    this.photoUrl,
    this.bio,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'photo_url': photoUrl,
      'bio': bio,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory CachedUser.fromMap(Map<String, dynamic> map) {
    return CachedUser(
      id: map['id'] as String,
      displayName: map['display_name'] as String?,
      photoUrl: map['photo_url'] as String?,
      bio: map['bio'] as String?,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

class PendingPost {
  final String id;
  final String userId;
  final String? content;
  final String? mediaUrl;
  final String? runId;
  final DateTime createdAt;
  final bool synced;

  PendingPost({
    required this.id,
    required this.userId,
    this.content,
    this.mediaUrl,
    this.runId,
    required this.createdAt,
    this.synced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'content': content,
      'media_url': mediaUrl,
      'run_id': runId,
      'created_at': createdAt.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  factory PendingPost.fromMap(Map<String, dynamic> map) {
    return PendingPost(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      content: map['content'] as String?,
      mediaUrl: map['media_url'] as String?,
      runId: map['run_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      synced: map['synced'] == 1,
    );
  }
}
