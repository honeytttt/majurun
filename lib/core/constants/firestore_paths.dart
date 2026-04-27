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

  // Misc
  static const String comments = 'comments';
  static const String routeRatings = 'routeRatings';
  static const String sosAlerts = 'sosAlerts';
  static const String contactMessages = 'contactMessages';
  static const String items = 'items';
  static const String attempts = 'attempts';
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
