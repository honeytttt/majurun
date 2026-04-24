import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import 'package:majurun/modules/profile/presentation/screens/profile_settings_screen.dart';
import 'package:majurun/core/services/storage_service.dart';
import 'package:majurun/core/services/badge_service.dart';
import 'package:majurun/core/utils/user_counters_initializer.dart';
import 'package:majurun/modules/profile/presentation/widgets/badge_chip.dart';
import 'package:majurun/modules/profile/presentation/screens/followers_following_screen.dart';
import 'package:majurun/core/widgets/user_avatar.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/presentation/widgets/post_card.dart';
import 'package:majurun/core/services/user_stats_service.dart';
import 'package:majurun/modules/dm/presentation/screens/privacy_settings_screen.dart';
import 'package:majurun/modules/profile/presentation/screens/contact_us_screen.dart';
import 'package:majurun/modules/profile/presentation/screens/voice_settings_screen.dart';
import 'package:majurun/modules/profile/presentation/screens/about_screen.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import 'package:majurun/core/services/push_notification_service.dart';
import 'package:majurun/core/services/weekly_summary_service.dart';
import 'package:majurun/core/services/streak_service.dart';

/// Professional Profile Screen - Your Own Profile
/// Matches UserProfileScreen design with Stats/Posts toggle
class ProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentBio;
  final String currentImageUrl;
  final String currentEmail;
  final Function(String, String, dynamic, String) onSave;
  final VoidCallback onBack;

  const ProfileScreen({
    super.key,
    required this.currentName,
    required this.currentBio,
    required this.currentImageUrl,
    required this.currentEmail,
    required this.onSave,
    required this.onBack,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _showPosts = true;  // Show Posts by default

  @override
  void initState() {
    super.initState();
    // Sync badges from run history when profile loads
    _syncBadges();
  }

  Future<void> _syncBadges() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await UserCountersInitializer.syncBadgesFromRunHistory(uid);
      // Recalculate totalKm and workoutsCount from actual run history
      // so profile stats always match the run history screen
      await UserStatsService().recalculateAndSyncStats(uid);
    }
  }

  void _navigateToSettings({
    required String name,
    required String bio,
    required String imageUrl,
    required String email,
    required String location,
    String nickname = '',
    String phoneNumber = '',
  }) {
    // Capture ProfileScreen's context before entering the builder.
    // The builder's (context) parameter refers to the settings screen's context,
    // which is unmounted once ProfileSettingsScreen pops itself, so snackbars
    // shown after the pop must use this outer context instead.
    final profileContext = context;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (builderContext) => ProfileSettingsScreen(
          currentName: name,
          currentBio: bio,
          currentImageUrl: imageUrl,
          currentEmail: email,
          currentLocation: location,
          currentNickname: nickname,
          currentPhone: phoneNumber,
          onSave: (newName, newBio, imageData, newEmail, newLocation, newNickname, newPhone) async {
            dynamic uploadedImageUrl = imageUrl;

            if (kIsWeb && imageData is Uint8List) {
              debugPrint("📤 Uploading from ProfileScreen...");
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
                final fileName = "profile_${user.uid}_$timestamp.png";
                uploadedImageUrl = await StorageService().uploadMedia(imageData, fileName, false);
              }
            }

            // Update Firestore with location, nickname and updatedAt
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
                'location': newLocation,
                'nickname': newNickname,
                if (newPhone.isNotEmpty) 'phoneNumber': newPhone,
                'updatedAt': FieldValue.serverTimestamp(),
              });
            }

            await widget.onSave(newName, newBio, uploadedImageUrl, newEmail);

            // ProfileSettingsScreen pops itself (profile_settings_screen.dart).
            // Do NOT pop here — that would double-pop and black-screen the user.
            // Use profileContext (ProfileScreen) for the snackbar since the
            // settings screen context is unmounted by the time we reach here.
            if (profileContext.mounted) {
              ScaffoldMessenger.of(profileContext).showSnackBar(
                const SnackBar(content: Text("Profile updated successfully!")),
              );
            }
          },
        ),
      ),
    );
  }

  void _navigateToFollowersFollowing(
    bool showFollowers,
    String userId,
    String userName,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowersFollowingScreen(
          userId: userId,
          userName: userName,
          initialTab: showFollowers ? 0 : 1,
        ),
      ),
    );
  }

  void _navigateToPrivacySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PrivacySettingsScreen(),
      ),
    );
  }

  void _navigateToVoiceSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VoiceSettingsScreen(),
      ),
    );
  }

  void _navigateToContactUs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactUsScreen(),
      ),
    );
  }

  void _navigateToAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AboutScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("Not logged in"));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 140,
        leading: Row(
          children: [
            Semantics(
              button: true,
              label: 'Go back',
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: widget.onBack,
              ),
            ),
            Semantics(
              button: true,
              label: 'About app',
              child: IconButton(
                icon: const Icon(Icons.info_outline, color: Color(0xFF00E676)),
                tooltip: 'About',
                onPressed: _navigateToAbout,
              ),
            ),
            Semantics(
              button: true,
              label: 'Contact support',
              child: IconButton(
                icon: const Icon(Icons.support_agent, color: Color(0xFF00E676)),
                tooltip: 'Contact Us',
                onPressed: _navigateToContactUs,
              ),
            ),
          ],
        ),
        title: const Text(
          "MY PROFILE",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        actions: [
          // Share Profile Button
          Semantics(
            button: true,
            label: 'Share profile',
            child: IconButton(
              icon: const Icon(Icons.share_outlined, color: Color(0xFF00E676)),
              tooltip: 'Share Profile',
              onPressed: () {
                SharePlus.instance.share(ShareParams(
                  text: 'Check out ${widget.currentName}\'s profile on MajuRun! 🏃‍♂️ #MajuRun',
                ));
              },
            ),
          ),
          // Voice Coach Settings Button
          Semantics(
            button: true,
            label: 'Voice coach settings',
            child: IconButton(
              icon: const Icon(Icons.record_voice_over, color: Colors.blue),
              tooltip: 'Voice Coach Settings',
              onPressed: _navigateToVoiceSettings,
            ),
          ),
          // Privacy Settings Button
          Semantics(
            button: true,
            label: 'Privacy settings',
            child: IconButton(
              icon: const Icon(Icons.privacy_tip, color: Colors.black),
              tooltip: 'Privacy Settings',
              onPressed: _navigateToPrivacySettings,
            ),
          ),
          // Sign Out Button
          Semantics(
            button: true,
            label: 'Sign out',
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: 'Sign Out',
              onPressed: () => _showSignOutDialog(context),
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
          }

          final data = (snap.data!.data() as Map<String, dynamic>?) ?? {};

          final name = (data['displayName'] ?? widget.currentName) as String;
          final bio = (data['bio'] ?? widget.currentBio) as String;
          final imageUrl = (data['photoUrl'] ?? widget.currentImageUrl) as String;
          final email = (data['email'] ?? widget.currentEmail) as String;
          final location = (data['location'] as String?) ?? '';
          final nickname = (data['nickname'] as String?) ?? '';
          final phoneNumber = (data['phoneNumber'] as String?) ?? '';
          final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

          final followersCount = (data['followersCount'] as int?) ?? 0;
          final followingCount = (data['followingCount'] as int?) ?? 0;
          
          // Run stats
          final totalKm = (data['totalKm'] as num?)?.toDouble() ?? 0.0;
          final bestPaceSecPerKm = (data['bestPaceSecPerKm'] as num?)?.toInt();
          
          debugPrint('📊 ProfileScreen Stats:');
          debugPrint('   totalKm from Firestore: $totalKm');
          debugPrint('   bestPaceSecPerKm from Firestore: $bestPaceSecPerKm');
          
          String bestPace = '--:--';
          if (bestPaceSecPerKm != null && bestPaceSecPerKm > 0) {
            final minutes = bestPaceSecPerKm ~/ 60;
            final seconds = bestPaceSecPerKm % 60;
            bestPace = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('userId', isEqualTo: uid)
                .snapshots(),
            builder: (context, postsSnapshot) {
              final postsCount = postsSnapshot.data?.docs.length ?? 0;
              // Get totalRuns from workoutsCount (run history), not postsCount
              final totalRuns = (data['workoutsCount'] as int?) ?? 0;

              return RefreshIndicator(
                color: const Color(0xFF00E676),
                backgroundColor: Colors.white,
                onRefresh: () async {
                  await _syncBadges();
                },
                child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildProfileHeader(
                      name: name,
                      bio: bio,
                      imageUrl: imageUrl,
                      email: email,
                      phoneNumber: phoneNumber,
                      followersCount: followersCount,
                      followingCount: followingCount,
                      postsCount: postsCount,
                      userId: uid,
                      location: location,
                      nickname: nickname,
                      createdAt: createdAt,
                    ),
                  ),

                  // Show either stats or posts based on toggle
                  if (_showPosts)
                    _buildPostsList(uid, name)
                  else
                    SliverToBoxAdapter(
                      child: _buildRunStats(
                        totalKm: totalKm,
                        bestPace: bestPace,
                        totalRuns: totalRuns,
                        postsCount: postsCount,
                        userId: uid,
                      ),
                    ),
                  
                  if (!_showPosts)
                    SliverToBoxAdapter(
                      child: _buildNotificationFixer(),
                    ),

                  // Bottom padding so last item isn't hidden behind system navigation bar
                  const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
                ],
              ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader({
    required String name,
    required String bio,
    required String imageUrl,
    required String email,
    required int followersCount,
    required int followingCount,
    required int postsCount,
    required String userId,
    required String location,
    String nickname = '',
    String phoneNumber = '',
    DateTime? createdAt,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00E676).withValues(alpha: 0.1),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        children: [
          // Avatar
          DirectUrlAvatar(
            imageUrl: imageUrl,
            radius: 50,
            showBorder: true,
            borderColor: const Color(0xFF00E676),
            borderWidth: 3,
          ),
          const SizedBox(height: 16),
          
          // Name
          Text(
            name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          
          // Bio
          if (bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                bio,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ),
          const SizedBox(height: 8),

          // Private phone number — only visible on own profile
          if (phoneNumber.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.phone_outlined, size: 13, color: Colors.grey[600]),
                  const SizedBox(width: 5),
                  Text(
                    phoneNumber,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 5),
                  Tooltip(
                    message: 'Only you can see this',
                    child: Icon(Icons.lock_outline, size: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Location & Joined Date Row
          _buildLocationJoinedRow(location: location, createdAt: createdAt),
          const SizedBox(height: 16),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Semantics(
                label: '$postsCount posts',
                child: GestureDetector(
                  onTap: () {},
                  child: _buildStatColumn('Posts', postsCount.toString()),
                ),
              ),
              Semantics(
                button: true,
                label: '$followersCount followers, tap to view',
                child: GestureDetector(
                  onTap: () => _navigateToFollowersFollowing(true, userId, name),
                  child: _buildStatColumn('Followers', followersCount.toString()),
                ),
              ),
              Semantics(
                button: true,
                label: '$followingCount following, tap to view',
                child: GestureDetector(
                  onTap: () => _navigateToFollowersFollowing(false, userId, name),
                  child: _buildStatColumn('Following', followingCount.toString()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            child: Semantics(
              button: true,
              label: 'Edit your profile',
              child: ElevatedButton(
                onPressed: () => _navigateToSettings(
                  name: name,
                  bio: bio,
                  imageUrl: imageUrl,
                  email: email,
                  location: location,
                  nickname: nickname,
                  phoneNumber: phoneNumber,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Posts/Stats Toggle Buttons (Posts first, Stats second)
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  selected: _showPosts,
                  label: 'Show posts${_showPosts ? ", selected" : ""}',
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showPosts = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _showPosts ? const Color(0xFF00E676) : Colors.grey[200],
                      foregroundColor: _showPosts ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Posts', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  selected: !_showPosts,
                  label: 'Show stats${!_showPosts ? ", selected" : ""}',
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showPosts = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !_showPosts ? const Color(0xFF00E676) : Colors.grey[200],
                      foregroundColor: !_showPosts ? Colors.white : Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Stats', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Location & Joined Date Row
  Widget _buildLocationJoinedRow({required String location, DateTime? createdAt}) {
    final hasLocation = location.isNotEmpty;
    final hasJoinedDate = createdAt != null;

    if (!hasLocation && !hasJoinedDate) {
      return const SizedBox.shrink();
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        if (hasLocation)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[700]),
              const SizedBox(width: 4),
              Text(
                location,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
        if (hasJoinedDate)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[700]),
              const SizedBox(width: 4),
              Text(
                'Joined ${DateFormat('MMMM yyyy').format(createdAt)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStreakAndActivity(String userId) {
    return FutureBuilder<Map<String, dynamic>>(
      future: Future.wait([
        StreakService().updateStreak(userId),
        WeeklySummaryService().getCurrentWeekSummary(),
      ]).then((results) => {
        'streak': results[0] as Map<String, dynamic>,
        'summary': results[1] as WeeklySummary,
      }),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final data = snapshot.data!;
        final streakData = data['streak'] as Map<String, dynamic>;
        final summary = data['summary'] as WeeklySummary;
        final currentStreak = streakData['currentStreak'] as int? ?? 0;

        return Column(
          children: [
            // Streak Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.orange.shade700],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.white, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Streak',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$currentStreak Days',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (currentStreak >= 3)
                    const Icon(Icons.stars, color: Colors.amberAccent, size: 24),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Weekly Activity Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Weekly Activity',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${summary.totalDistanceKm.toStringAsFixed(1)} km',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00E676),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(7, (index) {
                      final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      final dayRuns = summary.runsByDay[index + 1];
                      final hasRun = dayRuns != null && dayRuns.runs > 0;
                      
                      return Column(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: hasRun ? const Color(0xFF00E676) : Colors.grey[100],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: hasRun ? const Color(0xFF00E676) : Colors.grey[300]!,
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: hasRun ? Colors.white : Colors.transparent,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            days[index],
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRunStats({
    required double totalKm,
    required String bestPace,
    required int totalRuns,
    required int postsCount,
    required String userId,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Running Stats',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 20),

          // Run Streak & Weekly Activity
          _buildStreakAndActivity(userId),
          const SizedBox(height: 20),

          // Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.directions_run,
                  label: 'Total Distance',
                  value: '${totalKm.toStringAsFixed(2)} km',
                  color: const Color(0xFF00E676),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.timer,
                  label: 'Best Pace',
                  value: '$bestPace /km',
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.format_list_numbered,
                  label: 'Total Runs',
                  value: totalRuns.toString(),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.post_add,
                  label: 'Posts',
                  value: postsCount.toString(),
                  color: Colors.purple,
                ),
              ),
            ],
          ),

          // Badges Section
          const SizedBox(height: 24),
          Text(
            'Badges',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<RunnerBadge>>(
            stream: BadgeService().streamUserBadges(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(
                      color: Color(0xFF00E676),
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              final badges = snapshot.data ?? [];
              return BadgesDisplay(badges: badges);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationFixer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.notification_important, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Notification Fixer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'If your daily reminders aren\'t appearing, your phone may be blocking them to save battery.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => PushNotificationService().requestBatteryOptimizationExemption(),
                    icon: const Icon(Icons.battery_saver, size: 16),
                    label: const Text('Ignore Optimization'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => PushNotificationService().requestExactAlarmPermission(),
                    icon: const Icon(Icons.alarm, size: 16),
                    label: const Text('Allow Exact Alarms'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await PushNotificationService().sendTestNotification();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Test notification sent!')),
                    );
                  }
                },
                icon: const Icon(Icons.send, size: 16),
                label: const Text('Send Test Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsList(String userId, String username) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Error loading posts: ${snapshot.error}'),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.post_add, size: 60, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No posts yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              
              final post = AppPost(
                id: doc.id,
                userId: data['userId'] ?? 'unknown',
                username: data['username'] ?? username,
                content: data['content'] ?? '',
                media: _parseMedia(data['media'], data['mapImageUrl']),
                createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
                likes: List<String>.from(data['likes'] ?? []),
                comments: const [],
                quotedPostId: data['quotedPostId'],
                routePoints: _parseRoutePoints(data['routePoints']),
              );

              return PostCard(post: post);
            },
            childCount: docs.length,
          ),
        );
      },
    );
  }

  List<PostMedia> _parseMedia(dynamic mediaData, dynamic mapImageUrl) {
    List<PostMedia> mediaList = [];
    
    if (mediaData is List && mediaData.isNotEmpty) {
      mediaList = mediaData.map((m) {
        if (m is! Map) return null;
        final url = m['url'] as String? ?? '';
        final typeStr = m['type'] as String? ?? 'image';
        return PostMedia(
          url: url,
          type: typeStr == 'video' ? MediaType.video : MediaType.image,
        );
      }).whereType<PostMedia>().toList();
    }
    
    if (mediaList.isEmpty && mapImageUrl != null && mapImageUrl.toString().isNotEmpty) {
      mediaList.add(PostMedia(
        url: mapImageUrl.toString(),
        type: MediaType.image,
      ));
    }
    
    return mediaList;
  }

  List<LatLng>? _parseRoutePoints(dynamic routeData) {
    if (routeData == null || routeData is! List) return null;
    
    return routeData.map((p) {
      if (p is! Map) return null;
      final lat = (p['lat'] as num?)?.toDouble();
      final lng = (p['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    }).whereType<LatLng>().toList();
  }

  // Sign Out Dialog
  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[700], size: 28),
              const SizedBox(width: 12),
              const Text(
                'Sign Out',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to sign out?',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => _signOut(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Sign Out Function
  Future<void> _signOut(BuildContext context) async {
    try {
      // Close dialog
      Navigator.pop(context);
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00E676),
          ),
        ),
      );
      
      // Sign out from Firebase (AuthWrapper will navigate to LoginScreen automatically)
      await FirebaseAuth.instance.signOut();

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
        // AuthWrapper detects auth state change and routes to LoginScreen — no manual navigation needed
      }
      
      debugPrint('✅ User signed out successfully');
    } catch (e) {
      debugPrint('❌ Sign out error: $e');
      
      if (context.mounted) {
        // Close loading dialog if still open
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}