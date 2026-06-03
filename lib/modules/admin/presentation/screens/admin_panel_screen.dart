import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:majurun/core/models/segment.dart';
import 'package:majurun/core/services/segment_service.dart';
import 'package:majurun/modules/segments/presentation/screens/segment_create_screen.dart';
import 'package:majurun/modules/segments/presentation/screens/segment_detail_screen.dart';
import 'package:majurun/modules/segments/presentation/screens/segment_list_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded), text: 'Users'),
            Tab(icon: Icon(Icons.article_rounded), text: 'Posts'),
            Tab(icon: Icon(Icons.terminal_rounded), text: 'Logs'),
            Tab(icon: Icon(Icons.route_rounded), text: 'Segments'),
            Tab(icon: Icon(Icons.settings_rounded), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _UsersTab(),
          _PostsTab(),
          _LogsTab(),
          _SegmentsTab(),
          _SettingsTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────── USERS TAB ───────────────────────────

class _UsersTab extends StatelessWidget {
  const _UsersTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No users found.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = docs[i].id;
            final name = data['displayName'] ?? data['firstName'] ?? 'Unknown';
            final email = data['email'] ?? '';
            final photo = data['photoUrl'] ?? '';
            return ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                    : null,
              ),
              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(email, style: const TextStyle(fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                tooltip: 'Delete user',
                onPressed: () => _confirmDeleteUser(context, uid, name),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteUser(BuildContext context, String uid, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          SizedBox(width: 8),
          Text('Delete User'),
        ]),
        content: Text(
          'Delete "$name"?\n\nThis removes their Firebase Auth account, profile, all runs, and posts. This cannot be undone.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteUser(context, uid, name);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteUser(BuildContext context, String uid, String name) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      await fn.httpsCallable('adminDeleteUser').call({'uid': uid});
      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted user: $name'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

// ─────────────────────────── POSTS TAB ───────────────────────────

class _PostsTab extends StatelessWidget {
  const _PostsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('No posts found.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final postId = docs[i].id;
            final content = (data['content'] ?? '').toString();
            final userId = data['userId'] ?? '';
            final userName = data['userName'] ?? 'Unknown';
            final preview = content.length > 80
                ? '${content.substring(0, 80)}…'
                : content.isEmpty ? '(no text)' : content;
            return ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.article_outlined, size: 20),
              ),
              title: Text(
                preview,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'By: $userName  •  uid: ${userId.length > 8 ? userId.substring(0, 8) : userId}…',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                tooltip: 'Delete post',
                onPressed: () => _confirmDeletePost(context, postId, preview),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeletePost(BuildContext context, String postId, String preview) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          SizedBox(width: 8),
          Text('Delete Post'),
        ]),
        content: Text(
          'Delete this post?\n\n"$preview"\n\nAll comments will also be deleted.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              await _deletePost(context, postId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(BuildContext context, String postId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      await fn.httpsCallable('adminDeletePost').call({'postId': postId});
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Post deleted.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

// ─────────────────────────── LOGS TAB ───────────────────────────

class _LogsTab extends StatefulWidget {
  const _LogsTab();
  @override
  State<_LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<_LogsTab> {
  String _selectedLevel = 'ERROR';
  static const _levels = ['ALL', 'WARNING', 'ERROR'];
  static const Map<String, Color> _levelColors = {
    'WARNING': Colors.orange,
    'ERROR':   Colors.red,
    'INFO':    Colors.green,
    'DEBUG':   Colors.blue,
    'VERBOSE': Colors.grey,
  };

  // Fetch all logs ordered by timestamp — level filtering is done client-side
  // to avoid needing a composite Firestore index (level + timestamp).
  Query<Map<String, dynamic>> get _query => FirebaseFirestore.instance
      .collection('app_logs')
      .orderBy('timestamp', descending: true)
      .limit(500);

  Future<void> _clearOldLogs() async {
    final cutoff = DateTime.now().subtract(const Duration(days: 2));
    final snap = await FirebaseFirestore.instance
        .collection('app_logs')
        .where('timestamp', isLessThan: Timestamp.fromDate(cutoff))
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted ${snap.docs.length} old log entries')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.grey.shade100,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Text('Level:', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              ..._levels.map((lvl) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(lvl, style: const TextStyle(fontSize: 12)),
                      selected: _selectedLevel == lvl,
                      onSelected: (_) => setState(() => _selectedLevel = lvl),
                    ),
                  )),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                tooltip: 'Clear logs older than 2 days',
                onPressed: _clearOldLogs,
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _query.snapshots(),
            builder: (ctx, snap) {
              if (snap.hasError) return Center(child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.redAccent)));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              // Client-side level filter — avoids composite Firestore index requirement
              final docs = snap.data!.docs.where((d) {
                if (_selectedLevel == 'ALL') return true;
                return (d.data() as Map<String, dynamic>)['level'] == _selectedLevel;
              }).toList();
              if (docs.isEmpty) return Center(child: Text('No $_selectedLevel logs', style: const TextStyle(color: Colors.grey)));
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d       = docs[i].data() as Map<String, dynamic>;
                  final level   = d['level'] as String? ?? 'DEBUG';
                  final tag     = d['tag'] as String? ?? 'App';
                  final message = d['message'] as String? ?? '';
                  final error   = d['error'] as String?;
                  final uid     = d['userId'] as String?;
                  final plat    = d['platform'] as String? ?? '';
                  final ts      = (d['timestamp'] as Timestamp?)?.toDate();
                  final color   = _levelColors[level] ?? Colors.grey;
                  return InkWell(
                    onTap: () => _showDetail(context, d),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                            child: Text(level.substring(0, level.length.clamp(0, 4)),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Text('[$tag]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
                                  const SizedBox(width: 4),
                                  Text(plat, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  const Spacer(),
                                  if (ts != null)
                                    Text(
                                      '${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')}:${ts.second.toString().padLeft(2,'0')}',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                ]),
                                Text(message, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                                if (error != null)
                                  Text('⚠ $error', style: const TextStyle(fontSize: 11, color: Colors.redAccent), maxLines: 1, overflow: TextOverflow.ellipsis),
                                if (uid != null)
                                  Text('uid: ${uid.length > 10 ? uid.substring(0,10) : uid}…', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> d) {
    final text = [
      'Level:    ${d['level']}',
      'Tag:      ${d['tag']}',
      'Platform: ${d['platform']}',
      'Release:  ${d['isRelease']}',
      'UserId:   ${d['userId'] ?? 'none'}',
      '', 'Message:', d['message'] ?? '',
      if (d['error'] != null) ...['\nError:', d['error']],
      if (d['stack'] != null) ...['\nStack:', d['stack']],
    ].join('\n');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Detail'),
        content: SingleChildScrollView(
          child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
            },
            child: const Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}

// ─────────────────────────── SEGMENTS TAB ─────────────────────────────────

class _SegmentsTab extends StatefulWidget {
  const _SegmentsTab();

  @override
  State<_SegmentsTab> createState() => _SegmentsTabState();
}

class _SegmentsTabState extends State<_SegmentsTab> {
  final _service = SegmentService();
  List<Segment>? _segments;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _segments = null);
    try {
      final segs = await _service.fetchAllSegments();
      if (mounted) setState(() => _segments = segs);
    } catch (_) {
      if (mounted) setState(() => _segments = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF00E676),
        foregroundColor: Colors.black,
        tooltip: 'Create segment',
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const SegmentCreateScreen()),
          );
          if (created ?? false) _load();
        },
        child: const Icon(Icons.add_rounded),
      ),
      body: _segments == null
          ? const Center(child: CircularProgressIndicator())
          : _segments!.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.route_rounded,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No segments yet',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SegmentListScreen()),
                        ),
                        child: const Text('View public list'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _segments!.length,
                    itemBuilder: (ctx, i) {
                      final seg = _segments![i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.route_rounded,
                              color: Color(0xFF00E676)),
                          title: Text(seg.name),
                          subtitle: Text(
                            '${seg.city.isNotEmpty ? '${seg.city} · ' : ''}'
                            '${seg.distanceKm > 0 ? '${seg.distanceKm.toStringAsFixed(1)} km · ' : ''}'
                            '${seg.effortCount} efforts',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                color: Colors.red),
                            tooltip: 'Delete segment',
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Delete segment?'),
                                  content: Text(
                                      'This will delete "${seg.name}" and all its efforts. This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, true),
                                        child: const Text('Delete',
                                            style: TextStyle(
                                                color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirmed ?? false) {
                                await _service.deleteSegment(seg.id);
                                _load();
                              }
                            },
                          ),
                          onTap: () => Navigator.push(
                            ctx,
                            MaterialPageRoute(
                                builder: (_) =>
                                    SegmentDetailScreen(segment: seg)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ─────────────────────────── SETTINGS TAB ───────────────────────────

class _SettingsTab extends StatefulWidget {
  const _SettingsTab();

  @override
  State<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<_SettingsTab> {
  bool _loading = false;
  String? _result;

  Future<void> _grantAdminClaim() async {
    setState(() { _loading = true; _result = null; });
    try {
      final fn = FirebaseFunctions.instanceFor(region: 'asia-southeast1');
      final res = await fn.httpsCallable('grantAdminClaim').call();
      setState(() => _result = res.data['message'] as String? ?? 'Done! Sign out and back in.');
    } on FirebaseFunctionsException catch (e) {
      setState(() => _result = 'Error: ${e.message}');
    } catch (e) {
      setState(() => _result = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin Claim',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Call this once to grant admin:true custom claim to the currently signed-in account. '
            'Sign out and back in after to activate.',
            style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _grantAdminClaim,
              icon: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.verified_user_rounded),
              label: const Text('Grant Admin Claim to My Account'),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _result!.startsWith('Error')
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _result!.startsWith('Error')
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
              ),
              child: Text(
                _result!,
                style: TextStyle(
                  color: _result!.startsWith('Error')
                      ? Colors.red.shade800
                      : Colors.green.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
