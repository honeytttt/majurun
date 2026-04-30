import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// LIVE DIAGNOSTIC SCREEN
/// This shows you EXACTLY what's in Firestore in real-time
class LiveDiagnosticScreen extends StatelessWidget {
  const LiveDiagnosticScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Guard: never expose live Firestore data in production builds
    if (!kDebugMode) {
      return const Scaffold(
        body: Center(child: Text('Not available')),
      );
    }

    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Diagnostic')),
        body: const Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Firestore Data'),
        backgroundColor: Colors.blue,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Current User Info
          _buildSection(
            'Current User',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('UID: ${currentUser.uid}'),
                Text('Email: ${currentUser.email ?? "N/A"}'),
                Text('Name: ${currentUser.displayName ?? "N/A"}'),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // User Document from Firestore
          _buildSection(
            'User Document (Firestore)',
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                }
                
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}', 
                    style: const TextStyle(color: Colors.red));
                }
                
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('❌ DOCUMENT DOES NOT EXIST!',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _createUserDocument(currentUser),
                        child: const Text('Create User Document'),
                      ),
                    ],
                  );
                }
                
                final data = snapshot.data!.data() as Map<String, dynamic>?;
                
                if (data == null) {
                  return const Text('Document exists but has no data');
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('✅ Document exists', 
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    const Divider(),
                    ...data.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 150,
                            child: Text(
                              '${e.key}:',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${e.value}',
                              style: TextStyle(
                                color: e.value == null ? Colors.red : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                    const Divider(),
                    _buildCounterCheck(data),
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Followers Count
          _buildSection(
            'Followers (Subcollection)',
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('followers')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                
                final count = snapshot.data!.docs.length;
                return Text(
                  'Count: $count documents',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: count > 0 ? Colors.green : Colors.grey,
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Following Count
          _buildSection(
            'Following (Subcollection)',
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .collection('following')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                
                final count = snapshot.data!.docs.length;
                return Text(
                  'Count: $count documents',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: count > 0 ? Colors.green : Colors.grey,
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Posts Count
          _buildSection(
            'My Posts',
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('userId', isEqualTo: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                
                final count = snapshot.data!.docs.length;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Count: $count posts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: count > 0 ? Colors.green : Colors.grey,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(height: 10),
                      const Text('First post:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('userId: ${snapshot.data!.docs.first.get('userId')}'),
                      Text('My UID: ${currentUser.uid}'),
                      Text('Match: ${snapshot.data!.docs.first.get('userId') == currentUser.uid ? "✅" : "❌"}'),
                    ],
                  ],
                );
              },
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Action Buttons
          ElevatedButton(
            onPressed: () => _fixUserDocument(context, currentUser.uid),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              padding: const EdgeInsets.all(16),
            ),
            child: const Text('🔧 Fix User Document Now'),
          ),
          
          const SizedBox(height: 10),
          
          ElevatedButton(
            onPressed: () => _testFollowPermissions(context, currentUser.uid),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: const EdgeInsets.all(16),
            ),
            child: const Text('🧪 Test Follow Permissions'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildCounterCheck(Map<String, dynamic> data) {
  final followersCount = data['followersCount'];
  final followingCount = data['followingCount'];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Counter Fields:',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),

      Row(
        children: [
          const Text('followersCount: '),
          Text(
            followersCount == null ? '❌ MISSING' : '✅ $followersCount',
            style: TextStyle(
              color: followersCount == null ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),

      Row(
        children: [
          const Text('followingCount: '), // <-- const added here
          Text(
            followingCount == null ? '❌ MISSING' : '✅ $followingCount',
            style: TextStyle(
              color: followingCount == null ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ],
  );
}

  Future<void> _createUserDocument(User user) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': user.displayName ?? user.email?.split('@')[0] ?? 'Runner',
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'bio': '',
        'followersCount': 0,
        'followingCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ User document created!');
    } catch (e) {
      debugPrint('❌ Error creating user document: $e');
    }
  }

  Future<void> _fixUserDocument(BuildContext context, String uid) async {
    try {
      debugPrint('🔧 Fixing user document...');
      
      // Count subcollections
      final followersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('followers')
          .get();
      
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      
      final currentUser = FirebaseAuth.instance.currentUser!;
      
      // Update/create document
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Runner',
        'email': currentUser.email ?? '',
        'photoUrl': currentUser.photoURL ?? '',
        'bio': '',
        'followersCount': followersSnapshot.docs.length,
        'followingCount': followingSnapshot.docs.length,
      }, SetOptions(merge: true));
      
      debugPrint('✅ User document fixed!');
      debugPrint('   followersCount: ${followersSnapshot.docs.length}');
      debugPrint('   followingCount: ${followingSnapshot.docs.length}');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Fixed! Check the data above.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _testFollowPermissions(BuildContext context, String uid) async {
    const testUserId = 'test_follow_user_123';
    
    try {
      debugPrint('🧪 Testing follow permissions...');
      
      // Try to create a following document
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('following')
          .doc(testUserId)
          .set({
        'userId': testUserId,
        'followedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('✅ SUCCESS: Can create following document');
      
      // Clean up
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('following')
          .doc(testUserId)
          .delete();
      
      debugPrint('✅ Cleanup complete');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Follow permissions work!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ FAILED: Cannot create following document');
      debugPrint('   Error: $e');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Permission Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}