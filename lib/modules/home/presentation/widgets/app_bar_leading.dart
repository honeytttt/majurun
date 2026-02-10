// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// AppBarLeading - Top banner component with real avatar
/// Used across all screens: Home, Workouts, Posts, Rewards, Run
class AppBarLeading extends StatelessWidget {
  final VoidCallback onProfilePressed;

  const AppBarLeading({
    super.key,
    required this.onProfilePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        _buildProfileAvatar(),
        const SizedBox(width: 12),
        IconButton(
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.question_answer_outlined,
            color: Colors.black,
            size: 24,
          ),
          onPressed: () => debugPrint("Forum clicked"),
        ),
      ],
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
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          debugPrint('✅ AppBarLeading: Avatar loaded successfully');
                          return child;
                        }
                        
                        final progress = loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / 
                              loadingProgress.expectedTotalBytes!
                            : 0.0;
                        
                        debugPrint('⏳ AppBarLeading: Loading avatar... ${(progress * 100).toStringAsFixed(0)}%');
                        
                        return Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 2,
                                color: const Color(0xFF00E676),
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('❌ AppBarLeading: Image load ERROR');
                        debugPrint('   URL: $photoUrl');
                        debugPrint('   Error: $error');
                        debugPrint('   Error type: ${error.runtimeType}');
                        
                        return Container(
                          color: Colors.blueGrey,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          ),
                        );
                      },
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