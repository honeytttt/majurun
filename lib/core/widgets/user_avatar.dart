import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/cloudinary_service.dart';
import 'user_avatar_impl.dart'
    if (dart.library.io) 'user_avatar_io.dart'
    if (dart.library.js_interop) 'user_avatar_web.dart';

/// UserAvatar Widget - Displays user profile picture from Firestore
/// 
/// This widget fetches and displays a user's profile picture based on their userId.
/// It includes loading states, error handling, and uses platform-specific rendering.
/// 
/// Usage:
/// ```dart
/// UserAvatar(
///   userId: post.userId,
///   radius: 20,
/// )
/// ```

class UserAvatar extends StatelessWidget {
  final String userId;
  final double radius;
  final bool showBorder;
  final Color borderColor;
  final double borderWidth;
  
  const UserAvatar({
    super.key,
    required this.userId,
    this.radius = 20,
    this.showBorder = false,
    this.borderColor = Colors.white,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return _buildFallback();

    // Use .get() not .snapshots() — avatars don't need a permanent live listener.
    // snapshots() keeps a Firestore connection open per avatar in the feed,
    // which multiplies quickly (20 posts = 20 open connections).
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }
        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return _buildFallback();
        }
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return _buildFallback();

        final photoUrl = data['photoUrl'] as String? ?? '';
        if (photoUrl.isEmpty || !photoUrl.trim().startsWith('http')) {
          return _buildFallback();
        }
        // Apply Cloudinary thumbnail optimization — serve small image for avatars
        final optimizedUrl = CloudinaryService.thumbnailUrl(
          photoUrl.trim(),
          size: (radius * 2).toInt(),
        );
        return _buildImageAvatar(optimizedUrl);
      },
    );
  }

  /// Build avatar with platform-specific rendering
  Widget _buildImageAvatar(String imageUrl) {
    final avatar = buildUserAvatar(
      photoUrl: imageUrl,
      radius: radius,
    );
    
    // Add border if requested
    if (showBorder) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        child: avatar,
      );
    }
    
    return avatar;
  }
  
  /// Loading state
  Widget _buildLoading() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: SizedBox(
        width: radius * 0.6,
        height: radius * 0.6,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF00E676),
        ),
      ),
    );
  }
  
  /// Fallback icon when no image available
  Widget _buildFallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: Icon(
        Icons.person,
        size: radius * 0.8,
        color: Colors.grey.shade600,
      ),
    );
  }
}

// ============================================================================
// ALTERNATIVE: DirectUrlAvatar - for when you already have the photoUrl
// ============================================================================
/// DirectUrlAvatar - Displays an avatar when you already have the image URL
/// 
/// Use this instead of UserAvatar when you already have the photoUrl
/// (e.g., from the current user's auth object or cached data)
/// 
/// Usage:
/// ```dart
/// DirectUrlAvatar(
///   imageUrl: currentUser.photoURL ?? '',
///   radius: 55,
/// )
/// ```

class DirectUrlAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final bool showBorder;
  final Color borderColor;
  final double borderWidth;
  
  const DirectUrlAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 20,
    this.showBorder = false,
    this.borderColor = Colors.white,
    this.borderWidth = 2,
  });
  
  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    
    if (cleanUrl.isEmpty || !cleanUrl.startsWith('http')) {
      return _buildFallback();
    }

    final optimizedUrl = CloudinaryService.thumbnailUrl(
      cleanUrl,
      size: (radius * 2).toInt(),
    );
    final avatar = buildUserAvatar(
      photoUrl: optimizedUrl,
      radius: radius,
    );
    
    // Add border if requested
    if (showBorder) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        child: avatar,
      );
    }
    
    return avatar;
  }
  
  Widget _buildFallback() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: Icon(Icons.person, size: radius * 0.8, color: Colors.grey.shade600),
    );
  }
}