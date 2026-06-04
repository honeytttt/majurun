// ignore_for_file: prefer_const_constructors

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:majurun/core/services/dm_service.dart';
import 'package:majurun/modules/dm/presentation/screens/conversations_list_screen.dart';

/// AppBarLeading - Top banner component with real avatar
/// Used across all screens: Home, Workouts, Posts, Rewards, Run
class AppBarLeading extends StatelessWidget {
  final VoidCallback onProfilePressed;
  final DmService _dmService = DmService();

  AppBarLeading({
    super.key,
    required this.onProfilePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildProfileAvatar(),
        _buildDmIcon(context),
      ],
    );
  }

  Widget _buildDmIcon(BuildContext context) {
    return StreamBuilder<int>(
      stream: _dmService.getTotalUnreadCountStream(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return Stack(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.mail_outline,
                color: Colors.black,
                size: 24,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ConversationsListScreen(),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildProfileAvatar() {
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      // User not logged in - show default icon
      return IconButton(
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.account_circle_outlined,
          color: Colors.black,
          size: 28,
        ),
        onPressed: onProfilePressed,
      );
    }

    // ✅ Fetch real avatar from Firestore
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint('🎭 AppBarLeading: StreamBuilder state = ${snapshot.connectionState}');
        
        String photoUrl = '';
        
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          photoUrl = data?['photoUrl'] as String? ?? '';
          
          debugPrint('🎭 AppBarLeading: User data received');
          debugPrint('   photoUrl = "$photoUrl"');
          debugPrint('   length = ${photoUrl.length}');
          debugPrint('   starts with http = ${photoUrl.startsWith('http')}');
        } else {
          debugPrint('⚠️  AppBarLeading: No user data or doc does not exist');
        }

        return GestureDetector(
          onTap: onProfilePressed,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF00E676),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: photoUrl.isNotEmpty && photoUrl.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: photoUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[300],
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00E676),
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.blueGrey,
                        child: const Icon(Icons.person, color: Colors.white, size: 24),
                      ),
                    )
                  : Container(
                      color: Colors.blueGrey,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}