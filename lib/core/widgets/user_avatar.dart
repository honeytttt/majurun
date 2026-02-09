import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// UserAvatar Widget - Displays user profile picture from Firestore
/// 
/// This widget fetches and displays a user's profile picture based on their userId.
/// It includes loading states, error handling, and automatic retries.
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
    // CRITICAL: Log the userId being passed
    debugPrint('👤 UserAvatar: Loading for userId="$userId"');
    
    if (userId.isEmpty) {
      debugPrint('❌ UserAvatar: Empty userId provided');
      return _buildFallback();
    }
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        // Debug connection state
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          debugPrint('⏳ UserAvatar: Loading user data for $userId...');
          return _buildLoading();
        }
        
        if (snapshot.hasError) {
          debugPrint('❌ UserAvatar: Firestore error for $userId: ${snapshot.error}');
          return _buildFallback();
        }
        
        if (!snapshot.hasData || !snapshot.data!.exists) {
          debugPrint('❌ UserAvatar: No user document found for $userId');
          return _buildFallback();
        }
        
        final data = snapshot.data!.data() as Map<String, dynamic>?;
        
        if (data == null) {
          debugPrint('❌ UserAvatar: User data is null for $userId');
          return _buildFallback();
        }
        
        final photoUrl = data['photoUrl'] as String? ?? '';
        
        // CRITICAL: Log the actual photoUrl value
        debugPrint('📸 UserAvatar: photoUrl for $userId = "$photoUrl"');
        
        if (photoUrl.isEmpty) {
          debugPrint('⚠️ UserAvatar: Empty photoUrl for $userId');
          return _buildFallback();
        }
        
        // Validate URL format
        final cleanUrl = photoUrl.trim();
        if (!cleanUrl.startsWith('http')) {
          debugPrint('❌ UserAvatar: Invalid URL format for $userId: $cleanUrl');
          return _buildFallback();
        }
        
        return _buildImageAvatar(cleanUrl);
      },
    );
  }
  
  /// Build avatar with image
  Widget _buildImageAvatar(String imageUrl) {
    debugPrint('🖼️ UserAvatar: Rendering image avatar with URL: ${imageUrl.substring(0, imageUrl.length.clamp(0, 60))}...');
    
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: Image.network(
          imageUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          // Add headers for better compatibility
          headers: const {
            'Accept': 'image/*',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              debugPrint('✅ UserAvatar: Image loaded successfully for $userId');
              return child;
            }
            
            final percent = loadingProgress.expectedTotalBytes != null
                ? (loadingProgress.cumulativeBytesLoaded / 
                   loadingProgress.expectedTotalBytes! * 100).toInt()
                : null;
            
            if (percent != null && percent % 25 == 0) {
              debugPrint('⏳ UserAvatar: Loading image... $percent%');
            }
            
            return Center(
              child: SizedBox(
                width: radius * 0.6,
                height: radius * 0.6,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: const Color(0xFF00E676),
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ UserAvatar: Failed to load image for $userId');
            debugPrint('   URL: $imageUrl');
            debugPrint('   Error: $error');
            debugPrint('   Error type: ${error.runtimeType}');
            
            // Log first 3 lines of stack trace
            if (stackTrace != null) {
              final stackLines = stackTrace.toString().split('\n').take(3).join('\n');
              debugPrint('   Stack: $stackLines');
            }
            
            return Icon(
              Icons.person,
              size: radius * 0.8,
              color: Colors.grey.shade600,
            );
          },
        ),
      ),
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
    
    debugPrint('🔗 DirectUrlAvatar: imageUrl="$cleanUrl"');
    
    if (cleanUrl.isEmpty || !cleanUrl.startsWith('http')) {
      debugPrint('❌ DirectUrlAvatar: Invalid URL');
      return _buildFallback();
    }
    
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: ClipOval(
        child: Image.network(
          cleanUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          headers: const {
            'Accept': 'image/*',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              debugPrint('✅ DirectUrlAvatar: Image loaded');
              return child;
            }
            return Center(
              child: SizedBox(
                width: radius * 0.6,
                height: radius * 0.6,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E676),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ DirectUrlAvatar: Error: $error');
            return Icon(
              Icons.person,
              size: radius * 0.8,
              color: Colors.grey.shade600,
            );
          },
        ),
      ),
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