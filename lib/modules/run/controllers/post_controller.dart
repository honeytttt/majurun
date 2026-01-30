import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:majurun/modules/run/controllers/run_state_controller.dart';

class PostController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String generateAIPost(String planTitle, String distance, String time, String pace, int calories) {
    final templates = [
      "Crushed $distance KM in $time at $pace pace! Torched $calories kcal 🔥 Beast mode activated.",
      "Run complete: $distance KM conquered in $time. Avg pace $pace. Feeling unstoppable 💪",
      "Another solid session: $distance KM done in $time with $pace pace. $calories kcal burned. Progress never stops!",
      "From start to finish — $distance KM smashed! Time $time, pace $pace. The grind continues 🏃‍♂️✨",
      "Logged $distance KM today at $pace pace in $time. $calories kcal down. Keep stacking wins!",
    ];

    final index = DateTime.now().millisecond % templates.length;
    String post = templates[index];

    if (planTitle != "Free Run") {
      post += "\nCrushed the $planTitle session!";
    }

    post += "\n\n#MajurunPro #RunStrong #FitnessJourney #${distance.replaceAll('.', '')}KM";

    return post;
  }

  Future<void> finalizeProPost(
    String aiContent,
    String videoUrl,
    {String? planTitle,
    required String distance,
    required int bpm}
  ) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final data = {
      'userId': user.uid,
      'username': user.displayName ?? 'Runner',
      'content': aiContent,
      'media': [
        {
          'url': videoUrl,
          'type': 'image',
        }
      ],
      'createdAt': FieldValue.serverTimestamp(),
      'likes': [],
      'planTitle': planTitle ?? "Free Run",
      'distance': double.tryParse(distance) ?? 0.0,
      'avgBpm': bpm,
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _firestore.collection('posts').add(data);
    } catch (e) {
      debugPrint("finalizeProPost error: $e");
      rethrow;
    }
  }
}