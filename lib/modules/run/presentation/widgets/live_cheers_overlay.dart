import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:majurun/core/services/remote_config_service.dart';

/// Engagement E3 — live-cheers overlay shown on the congratulations screen.
///
/// After a run finishes and the auto-post lands in Firestore, this widget:
///  1. Finds the user's most-recently-created post (within the last 90 s).
///  2. Listens to its `likes` field and `comments` subcollection.
///  3. Animates each new like/comment as a transient "cheer" bubble that floats
///     upward and fades. After ~60 s of listening, the overlay self-retires.
///
/// It's behind `RemoteConfigService.isLiveCheersEnabled` so the feature can be
/// killed without an app update if anything misbehaves in the wild. When
/// disabled, the widget renders an empty `SizedBox.shrink()` and never opens
/// any Firestore listener.
///
/// Designed to be drop-in: just append it to the congrats screen's column. It
/// occupies a fixed 96 px tall band; nothing else needs to change.
class LiveCheersOverlay extends StatefulWidget {
  const LiveCheersOverlay({super.key});

  @override
  State<LiveCheersOverlay> createState() => _LiveCheersOverlayState();
}

class _LiveCheersOverlayState extends State<LiveCheersOverlay>
    with TickerProviderStateMixin {
  static const _activeWindow = Duration(seconds: 60);
  static const _postLookbackSeconds = 90;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _postSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _postDocSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _commentsSub;
  Timer? _retireTimer;

  bool _retired = false;
  String? _postId;

  /// Likes UIDs we've already animated — prevents duplicate bubbles when the
  /// snapshot fires multiple times with the same array.
  final Set<String> _seenLikes = {};
  final Set<String> _seenComments = {};

  /// Currently-animated bubbles, each with its own controller so they fade
  /// independently. Removed from the list when the controller completes.
  final List<_CheerBubble> _bubbles = [];

  @override
  void initState() {
    super.initState();
    if (!RemoteConfigService().isLiveCheersEnabled) {
      _retired = true;
      return;
    }
    _attachToLatestPost();
    _retireTimer = Timer(_activeWindow, _retire);
  }

  void _attachToLatestPost() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _retire();
      return;
    }

    final cutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(seconds: _postLookbackSeconds)),
    );

    // We look for the user's most-recent post created in the lookback window.
    // The auto-post fires from active_run_screen just before navigation, so by
    // the time the congrats screen mounts the doc is typically a second or two
    // old. Limit 1 — we only care about the freshest one.
    _postSub = FirebaseFirestore.instance
        .collection('posts')
        .where('userId', isEqualTo: uid)
        .where('createdAt', isGreaterThan: cutoff)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty || _postId != null || _retired) return;
      _postId = snap.docs.first.id;
      // The query subscription has done its job — release it.
      _postSub?.cancel();
      _postSub = null;
      _attachLikeAndCommentListeners(_postId!);
    }, onError: (e) {
      debugPrint('LiveCheers: post query error: $e');
    });
  }

  void _attachLikeAndCommentListeners(String postId) {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    _postDocSub = postRef.snapshots().listen((doc) {
      if (_retired || !doc.exists) return;
      final likes = (doc.data()?['likes'] as List?)?.cast<String>() ?? const <String>[];
      final me = FirebaseAuth.instance.currentUser?.uid;
      for (final likerUid in likes) {
        if (likerUid == me) continue; // skip self
        if (_seenLikes.add(likerUid)) {
          _spawnBubble(_CheerKind.like, sourceUid: likerUid);
        }
      }
    }, onError: (e) {
      debugPrint('LiveCheers: post doc listener error: $e');
    });

    _commentsSub = postRef
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .listen((snap) {
      if (_retired) return;
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final id = change.doc.id;
        final me = FirebaseAuth.instance.currentUser?.uid;
        final senderId = change.doc.data()?['userId'] as String?;
        if (senderId == me) continue;
        if (_seenComments.add(id)) {
          _spawnBubble(_CheerKind.comment, sourceUid: senderId);
        }
      }
    }, onError: (e) {
      debugPrint('LiveCheers: comments listener error: $e');
    });
  }

  void _spawnBubble(_CheerKind kind, {String? sourceUid}) {
    if (!mounted || _retired) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    final bubble = _CheerBubble(kind: kind, sourceUid: sourceUid, controller: controller);
    setState(() => _bubbles.add(bubble));
    controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _bubbles.remove(bubble));
      controller.dispose();
    });
  }

  void _retire() {
    if (_retired) return;
    _retired = true;
    _postSub?.cancel();
    _postDocSub?.cancel();
    _commentsSub?.cancel();
    _retireTimer?.cancel();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _retire();
    for (final b in _bubbles) {
      b.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_retired && _bubbles.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // Static header strip — visible whenever we're listening.
          if (!_retired)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ListeningHeader(),
            ),
          // Live bubbles — each one animates its own slide+fade.
          ..._bubbles.map((b) => _AnimatedCheer(bubble: b)),
        ],
      ),
    );
  }
}

class _ListeningHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF7ED957).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF7ED957).withValues(alpha: 0.4)),
      ),
      child: const Row(
        children: [
          Icon(PhosphorIconsDuotone.megaphone,
              size: 16, color: Color(0xFF7ED957)),
          SizedBox(width: 8),
          Text(
            'Listening for cheers from your friends...',
            style: TextStyle(
              color: Color(0xFF7ED957),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          Spacer(),
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: Color(0xFF7ED957),
            ),
          ),
        ],
      ),
    );
  }
}

enum _CheerKind { like, comment }

class _CheerBubble {
  final _CheerKind kind;
  final String? sourceUid;
  final AnimationController controller;
  _CheerBubble({required this.kind, required this.sourceUid, required this.controller});
}

class _AnimatedCheer extends StatelessWidget {
  final _CheerBubble bubble;
  const _AnimatedCheer({required this.bubble});

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: const Offset(0, -0.4),
    ).animate(CurvedAnimation(parent: bubble.controller, curve: Curves.easeOutCubic));
    final fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(bubble.controller);

    return AnimatedBuilder(
      animation: bubble.controller,
      builder: (_, __) {
        return Positioned(
          bottom: 28,
          right: 32,
          child: SlideTransition(
            position: slide,
            child: FadeTransition(
              opacity: fade,
              child: _CheerChip(kind: bubble.kind),
            ),
          ),
        );
      },
    );
  }
}

class _CheerChip extends StatelessWidget {
  final _CheerKind kind;
  const _CheerChip({required this.kind});

  @override
  Widget build(BuildContext context) {
    final isLike = kind == _CheerKind.like;
    final accent = isLike ? const Color(0xFFFF4D6D) : const Color(0xFF00B96B);
    final icon = isLike ? PhosphorIconsFill.heart : PhosphorIconsFill.chatCircle;
    final label = isLike ? 'New like!' : 'New comment!';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.4),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
