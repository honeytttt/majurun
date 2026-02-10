import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:majurun/modules/profile/presentation/screens/profile_settings_screen.dart';
import 'package:majurun/core/services/storage_service.dart';
import 'package:majurun/modules/profile/presentation/screens/followers_following_screen.dart';
import 'package:majurun/core/widgets/user_avatar.dart';
import 'package:majurun/modules/home/domain/entities/post.dart';
import 'package:majurun/modules/home/presentation/widgets/post_card.dart';

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
  bool _showPosts = true;  // ✅ Changed: Show Posts by default (was false)

  void _navigateToSettings({
    required String name,
    required String bio,
    required String imageUrl,
    required String email,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileSettingsScreen(
          currentName: name,
          currentBio: bio,
          currentImageUrl: imageUrl,
          currentEmail: email,
          onSave: (newName, newBio, imageData, newEmail) async {
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

            await widget.onSave(newName, newBio, uploadedImageUrl, newEmail);

            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text("Not logged in"));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: widget.onBack,
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
          // ✅ Sign Out Button
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Sign Out',
            onPressed: () => _showSignOutDialog(context),
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

          final followersCount = (data['followersCount'] as int?) ?? 0;
          final followingCount = (data['followingCount'] as int?) ?? 0;
          
          // Run stats - with debug logging
          final totalKm = (data['totalKm'] as num?)?.toDouble() ?? 0.0;
          final bestPaceSecPerKm = (data['bestPaceSecPerKm'] as num?)?.toInt();
          
          debugPrint('📊 ProfileScreen Stats for USER: $uid');
          debugPrint('   displayName: $name');
          debugPrint('   totalKm from Firestore: $totalKm');
          debugPrint('   bestPaceSecPerKm from Firestore: $bestPaceSecPerKm');
          debugPrint('   Data keys: ${data.keys.toList()}');
          debugPrint('   Raw totalKm value: ${data['totalKm']}');
          debugPrint('   Raw bestPaceSecPerKm value: ${data['bestPaceSecPerKm']}');
          
          // Check if this user has any run data at all
          if (totalKm == 0.0 && bestPaceSecPerKm == null) {
            debugPrint('   ⚠️ WARNING: This user has NO running stats!');
            debugPrint('   ⚠️ Stats are not being synced when runs complete.');
            debugPrint('   ⚠️ Check RunController to ensure it updates user stats.');
          }
          
          String bestPace = '--:--';
          if (bestPaceSecPerKm != null && bestPaceSecPerKm > 0) {
            final minutes = bestPaceSecPerKm ~/ 60;
            final seconds = bestPaceSecPerKm % 60;
            bestPace = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
            debugPrint('   ✅ Calculated bestPace: $bestPace');
          } else {
            debugPrint('   ⚠️ No best pace data - user hasn\'t completed tracked runs');
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('posts')
                .where('userId', isEqualTo: uid)
                .snapshots(),
            builder: (context, postsSnapshot) {
              // Separate run posts from social posts
              int runPostsCount = 0;
              int socialPostsCount = 0;
              
              if (postsSnapshot.hasData) {
                for (final doc in postsSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type = data['type'] as String?;
                  
                  if (type == 'run_activity' || type == 'run_video') {
                    runPostsCount++;
                  } else {
                    socialPostsCount++;
                  }
                }
              }
              
              final totalRuns = runPostsCount; // Count only run-related posts
              final postsCount = socialPostsCount; // Count only social posts

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildProfileHeader(
                      name: name,
                      bio: bio,
                      imageUrl: imageUrl,
                      email: email,
                      followersCount: followersCount,
                      followingCount: followingCount,
                      postsCount: postsCount,
                      userId: uid,
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
                      ),
                    ),
                ],
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
                  color: Colors.grey[600],
                ),
              ),
            ),
          const SizedBox(height: 16),
          
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: () {}, // Could navigate to posts view
                child: _buildStatColumn('Posts', postsCount.toString()),
              ),
              GestureDetector(
                onTap: () => _navigateToFollowersFollowing(true, userId, name),
                child: _buildStatColumn('Followers', followersCount.toString()),
              ),
              GestureDetector(
                onTap: () => _navigateToFollowersFollowing(false, userId, name),
                child: _buildStatColumn('Following', followingCount.toString()),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _navigateToSettings(
                name: name,
                bio: bio,
                imageUrl: imageUrl,
                email: email,
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
          
          const SizedBox(height: 12),
          
          // ✅ Sync Stats Button (Temporary - remove after use)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _syncUserStatsFromPosts(context, name),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: const Text(
                '🔄 Sync Stats from Posts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Posts/Stats Toggle Buttons (Posts first, Stats second)
          Row(
            children: [
              Expanded(
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
              const SizedBox(width: 12),
              Expanded(
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
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRunStats({
    required double totalKm,
    required String bestPace,
    required int totalRuns,
    required int postsCount,
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
        ],
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
              color: Colors.grey[600],
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
              child: CircularProgressIndicator(),
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
                        color: Colors.grey[600],
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
              final data = doc.data() as Map<String, dynamic>;
              
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

  // ✅ Sign Out Dialog
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

  // ✅ Sign Out Function
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
      
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      // Navigate back to login screen or show success
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed out'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Go back to previous screen
        widget.onBack();
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

  // ✅ Sync Stats from Posts (One-Time Use)
  Future<void> _syncUserStatsFromPosts(BuildContext context, String username) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    
    if (uid == null) {
      debugPrint('❌ No user logged in');
      return;
    }
    
    debugPrint('📊 Syncing stats for user: $uid');

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00E676)),
        ),
      );

      // Get all posts for this user
      final postsSnapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('userId', isEqualTo: uid)
          .get();

      debugPrint('📝 Found ${postsSnapshot.docs.length} posts');

      if (postsSnapshot.docs.isEmpty) {
        debugPrint('⚠️ No posts found - nothing to sync');
        if (mounted) Navigator.pop(context);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No posts found to sync'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      double totalKm = 0.0;
      int totalRunSeconds = 0;
      int? bestPaceSecPerKm;
      int totalCalories = 0;
      int runsWithData = 0;
      int runPostsCount = 0;
      int socialPostsCount = 0;

      // Calculate stats from all posts
      for (final doc in postsSnapshot.docs) {
        final data = doc.data();
        
        // Check post type
        final type = data['type'] as String?;
        if (type == 'run_activity' || type == 'run_video') {
          runPostsCount++;
        } else {
          socialPostsCount++;
        }
        
        // Get distance - handle both String and num types
        double? distance;
        final distanceData = data['distance'];
        if (distanceData is String) {
          distance = double.tryParse(distanceData);
        } else if (distanceData is num) {
          distance = distanceData.toDouble();
        }
        
        // Get pace (stored as string like "5:30")
        final paceStr = data['pace'] as String?;
        
        // Calculate duration from distance and pace
        int? durationSeconds;
        int? paceSecPerKm;
        
        if (distance != null && distance > 0 && paceStr != null) {
          // Parse pace string "5:30" to seconds per km
          final paceParts = paceStr.split(':');
          if (paceParts.length == 2) {
            final minutes = int.tryParse(paceParts[0]) ?? 0;
            final seconds = int.tryParse(paceParts[1]) ?? 0;
            paceSecPerKm = (minutes * 60) + seconds;
            
            // Calculate total duration: distance * pace
            durationSeconds = (distance * paceSecPerKm).round();
          }
        }
        
        if (distance != null && distance > 0) {
          totalKm += distance;
          runsWithData++;
          
          debugPrint('  Run ${doc.id}: ${distance.toStringAsFixed(2)} km, pace: $paceStr');
          
          if (durationSeconds != null) {
            totalRunSeconds += durationSeconds;
          }
          
          // Update best pace if this is faster (lower is better)
          if (paceSecPerKm != null && paceSecPerKm > 0) {
            if (bestPaceSecPerKm == null || paceSecPerKm < bestPaceSecPerKm) {
              bestPaceSecPerKm = paceSecPerKm;
              final minutes = paceSecPerKm ~/ 60;
              final seconds = paceSecPerKm % 60;
              debugPrint('    New best pace: $minutes:${seconds.toString().padLeft(2, '0')} /km');
            }
          }
          
          // Estimate calories
          totalCalories += (distance * 60).round();
        }
      }

      debugPrint('\n📊 CALCULATED STATS:');
      debugPrint('   Total Distance: ${totalKm.toStringAsFixed(2)} km');
      debugPrint('   Total Duration: $totalRunSeconds seconds');
      debugPrint('   Total Calories: $totalCalories');
      debugPrint('   Runs with data: $runsWithData / $runPostsCount run posts');
      debugPrint('   Run Posts: $runPostsCount (type: run_activity or run_video)');
      debugPrint('   Social Posts: $socialPostsCount (manual posts)');
      debugPrint('   Total Posts: ${postsSnapshot.docs.length}');
      
      if (bestPaceSecPerKm != null) {
        final minutes = bestPaceSecPerKm ~/ 60;
        final seconds = bestPaceSecPerKm % 60;
        debugPrint('   Best Pace: $minutes:${seconds.toString().padLeft(2, '0')} /km');
      }

      // Update user document - separate run posts from social posts
      final updateData = {
        'totalKm': totalKm,
        'totalRunSeconds': totalRunSeconds,
        'totalCalories': totalCalories,
        'runPostsCount': runPostsCount,  // New: count of run posts
        'socialPostsCount': socialPostsCount,  // New: count of social posts
        'postsCount': postsSnapshot.docs.length,  // Total (for backwards compatibility)
      };

      if (bestPaceSecPerKm != null && bestPaceSecPerKm > 0) {
        updateData['bestPaceSecPerKm'] = bestPaceSecPerKm;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update(updateData);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      debugPrint('✅ Stats synced successfully!');

      // Show success message with stats
      if (mounted) {
        final paceStr = bestPaceSecPerKm != null 
            ? '${bestPaceSecPerKm ~/ 60}:${(bestPaceSecPerKm % 60).toString().padLeft(2, '0')}'
            : '--:--';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Synced ${totalKm.toStringAsFixed(2)} km from $runPostsCount runs!\n'
              'Social Posts: $socialPostsCount | Best Pace: $paceStr /km',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Refresh the page to show updated stats
      setState(() {});
      
    } catch (e) {
      debugPrint('❌ Error syncing stats: $e');
      debugPrint('   Error type: ${e.runtimeType}');
      
      // Close loading dialog
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error syncing stats: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}