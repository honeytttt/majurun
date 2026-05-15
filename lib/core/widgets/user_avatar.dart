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

class UserAvatar extends StatefulWidget {
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
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  // Cache the Future so parent rebuilds don't re-issue Firestore reads.
  // Each rebuild of a StatelessWidget would open a new .get() — in a feed
  // with 20 posts that means 20 reads per scroll frame.
  late final Future<DocumentSnapshot> _userFuture;

  @override
  void initState() {
    super.initState();
    if (widget.userId.isEmpty) return;
    _userFuture = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .get();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userId.isEmpty) return _buildFallback();

    return FutureBuilder<DocumentSnapshot>(
      future: _userFuture,
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
        final optimizedUrl = CloudinaryService.thumbnailUrl(
          photoUrl.trim(),
          size: (widget.radius * 2).toInt(),
        );
        return _buildImageAvatar(optimizedUrl);
      },
    );
  }

  Widget _buildImageAvatar(String imageUrl) {
    final avatar = buildUserAvatar(
      photoUrl: imageUrl,
      radius: widget.radius,
    );
    if (widget.showBorder) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.borderColor,
            width: widget.borderWidth,
          ),
        ),
        child: avatar,
      );
    }
    return avatar;
  }

  Widget _buildLoading() {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.grey.shade200,
      child: SizedBox(
        width: widget.radius * 0.6,
        height: widget.radius * 0.6,
        child: const CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFF00E676),
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: Colors.grey.shade200,
      child: Icon(
        Icons.person,
        size: widget.radius * 0.8,
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