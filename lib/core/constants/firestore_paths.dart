/// Centralized Firestore collection paths and field names.
///
/// Using these constants prevents typos and makes refactoring easier.
/// Always use these instead of hardcoding strings.
library;

/// Collection paths - all top-level Firestore collections
abstract class FirestoreCollections {
  // Core user data
  static const String users = 'users';
  static const String posts = 'posts';
  static const String notifications = 'notifications';

  // Social features
  static const String following = 'following';
  static const String followers = 'followers';
  static const String blockedUsers = 'blockedUsers';
  static const String conversations = 'conversations';
  static const String messages = 'messages';

  // Running data
  static const String runHistory = 'runHistory';
  static const String runs = 'runs';
  static const String routes = 'routes';
  static const String segments = 'segments';
  static const String segmentPRs = 'segmentPRs';
  static const String personalRecords = 'personalRecords';
  static const String durationRecords = 'durationRecords';
  static const String liveTracking = 'liveTracking';

  // Training
  static const String trainingHistory = 'training_history';
  static const String shoes = 'shoes';

  // Challenges & achievements
  static const String challenges = 'challenges';
  static const String dailyChallenges = 'dailyChallenges';
  static const String weeklyChallenges = 'weeklyChallenges';
  static const String monthlyChallenges = 'monthlyChallenges';
  static const String joinedChallenges = 'joinedChallenges';
  static const String completedChallenges = 'completedChallenges';
  static const String achievements = 'achievements';
  static const String goals = 'goals';
  static const String leaderboard = 'leaderboard';

  // Settings & privacy
  static const String settings = 'settings';
  static const String userNotificationSettings = 'userNotificationSettings';
  static const String userPrivacy = 'userPrivacy';

  // Clubs & races
  static const String clubs = 'clubs';
  static const String races = 'races';
  static const String entries = 'entries';

  // Misc
  static const String comments = 'comments';
  static const String routeRatings = 'routeRatings';
  static const String sosAlerts = 'sosAlerts';
  static const String contactMessages = 'contactMessages';
  static const String items = 'items';
  static const String attempts = 'attempts';
  static const String savedPosts = 'savedPosts';
  static const String efforts = 'efforts';
  static const String members = 'members';
}

/// Convenience path builders — produce slash-separated Firestore paths.
/// Use these wherever a path string is needed to avoid typos and make
/// refactoring a single-file change.
abstract class FirestorePaths {
  // Top-level document paths
  static String user(String uid)      => '${FirestoreCollections.users}/$uid';
  static String post(String postId)   => '${FirestoreCollections.posts}/$postId';

  // User subcollection paths
  static String userFollowers(String uid)          => '${user(uid)}/${FirestoreCollections.followers}';
  static String userFollowing(String uid)          => '${user(uid)}/${FirestoreCollections.following}';
  static String userTrainingHistory(String uid)    => '${user(uid)}/${FirestoreCollections.trainingHistory}';
  static String userDailyChallenges(String uid)    => '${user(uid)}/${FirestoreCollections.dailyChallenges}';
  static String userWeeklyChallenges(String uid)   => '${user(uid)}/${FirestoreCollections.weeklyChallenges}';
  static String userMonthlyChallenges(String uid)  => '${user(uid)}/${FirestoreCollections.monthlyChallenges}';
  static String userSavedPosts(String uid)         => '${user(uid)}/${FirestoreCollections.savedPosts}';
  static String userClubs(String uid)              => '${user(uid)}/${FirestoreCollections.clubs}';
  static String userNotifications(String uid)      => '${FirestoreCollections.notifications}/$uid/${FirestoreCollections.items}';
  static String userSettings(String uid)           => '${user(uid)}/${FirestoreCollections.settings}';

  // Club paths
  static String clubMembers(String clubId) => '${FirestoreCollections.clubs}/$clubId/${FirestoreCollections.members}';

  // Race paths
  static String raceEntries(String raceId) => '${FirestoreCollections.races}/$raceId/${FirestoreCollections.entries}';

  // Segment paths
  static String segmentEfforts(String segmentId) => '${FirestoreCollections.segments}/$segmentId/${FirestoreCollections.efforts}';

  /// Deterministic conversation ID for a DM thread between two users.
  /// Sorting ensures uid1_uid2 and uid2_uid1 resolve to the same document.
  static String conversationId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}

/// User document fields
abstract class UserFields {
  static const String displayName = 'displayName';
  static const String email = 'email';
  static const String photoUrl = 'photoUrl';
  static const String bio = 'bio';
  static const String createdAt = 'createdAt';
  static const String lastActive = 'lastActive';

  // Stats
  static const String followersCount = 'followersCount';
  static const String followingCount = 'followingCount';
  static const String postsCount = 'postsCount';
  static const String runsCount = 'runsCount';
  static const String totalDistance = 'totalDistance';
  static const String totalDuration = 'totalDuration';
  static const String trainingsCount = 'trainingsCount';

  // Settings
  static const String isPrivate = 'isPrivate';
  static const String fcmToken = 'fcmToken';
}

/// Post document fields
abstract class PostFields {
  static const String userId = 'userId';
  static const String username = 'username';
  static const String content = 'content';
  static const String media = 'media';
  static const String createdAt = 'createdAt';
  static const String likes = 'likes';
  static const String quotedPostId = 'quotedPostId';
  static const String routePoints = 'routePoints';
  static const String distance = 'distance';
  static const String avgBpm = 'avgBpm';
  static const String splits = 'splits';
  static const String type = 'type';
  static const String mapImageUrl = 'mapImageUrl';
  static const String tags = 'tags';

  // Post-run metadata (written via Quick Edit after run is saved)
  static const String feeling = 'feeling';    // 'tough'|'okay'|'good'|'great'|'amazing'
  static const String surface = 'surface';    // 'road'|'trail'|'treadmill'|'track'
  static const String privacy = 'privacy';    // 'everyone'|'followers'|'only_me'
}

/// Run history document fields
abstract class RunFields {
  static const String date = 'date';
  static const String distance = 'distance';
  static const String duration = 'duration';
  static const String pace = 'pace';
  static const String avgBpm = 'avgBpm';
  static const String maxBpm = 'maxBpm';
  static const String calories = 'calories';
  static const String steps = 'steps';
  static const String cadence = 'cadence';
  static const String routePoints = 'routePoints';
  static const String splits = 'splits';
  static const String mapImageUrl = 'mapImageUrl';
  static const String weather = 'weather';
  static const String shoeId = 'shoeId';
  static const String notes = 'notes';
  static const String isRace = 'isRace';
  static const String effortLevel = 'effortLevel';

  // Post-run quick-edit metadata
  static const String feeling = 'feeling';   // 'tough'|'okay'|'good'|'great'|'amazing'
  static const String surface = 'surface';   // 'road'|'trail'|'treadmill'|'track'
}

/// Notification document fields
abstract class NotificationFields {
  static const String targetUserId = 'targetUserId';
  static const String type = 'type';
  static const String fromUserId = 'fromUserId';
  static const String fromUsername = 'fromUsername';
  static const String fromUserPhotoUrl = 'fromUserPhotoUrl';
  static const String message = 'message';
  static const String metadata = 'metadata';
  static const String isRead = 'isRead';
  static const String createdAt = 'createdAt';
}

/// Comment document fields
abstract class CommentFields {
  static const String userId = 'userId';
  static const String username = 'username';
  static const String content = 'content';
  static const String parentId = 'parentId';
  static const String media = 'media';
  static const String likes = 'likes';
  static const String createdAt = 'createdAt';
}

/// Challenge document fields
abstract class ChallengeFields {
  static const String title = 'title';
  static const String description = 'description';
  static const String type = 'type';
  static const String goal = 'goal';
  static const String startDate = 'startDate';
  static const String endDate = 'endDate';
  static const String participants = 'participants';
  static const String createdBy = 'createdBy';
  static const String imageUrl = 'imageUrl';
  static const String reward = 'reward';
}

/// Message/conversation fields
abstract class MessageFields {
  static const String senderId = 'senderId';
  static const String receiverId = 'receiverId';
  static const String content = 'content';
  static const String mediaUrl = 'mediaUrl';
  static const String mediaType = 'mediaType';
  static const String createdAt = 'createdAt';
  static const String isRead = 'isRead';
  static const String participants = 'participants';
  static const String lastMessage = 'lastMessage';
  static const String lastMessageTime = 'lastMessageTime';
}
