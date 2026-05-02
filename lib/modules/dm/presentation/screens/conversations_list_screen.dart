import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/core/services/dm_service.dart';
import 'package:majurun/core/services/search_service.dart';
import 'package:majurun/modules/dm/domain/entities/conversation.dart';
import 'package:majurun/modules/dm/presentation/widgets/conversation_tile.dart';
import 'package:majurun/modules/dm/presentation/screens/chat_screen.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';

class ConversationsListScreen extends StatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  State<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends State<ConversationsListScreen> {
  final DmService _dmService = DmService();

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
        ),
        body: const Center(
          child: Text('Please log in to view messages'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Messages',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: Colors.black),
            tooltip: 'New message',
            onPressed: () => _showNewMessageSheet(context, currentUserId),
          ),
        ],
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: _dmService.getConversationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey[200],
            ),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return ConversationTile(
                conversation: conversation,
                currentUserId: currentUserId,
                onTap: () => _openChat(conversation),
                onLongPress: () => _showConversationOptions(conversation),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'No messages yet',
      subtitle: 'Tap the compose button to start a conversation with a fellow runner.',
    );
  }

  void _showNewMessageSheet(BuildContext context, String currentUserId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewMessageSheet(
        currentUserId: currentUserId,
        dmService: _dmService,
        onConversationOpened: (conversationId, otherUserId, otherUserName, otherUserPhoto) {
          Navigator.pop(context); // close sheet
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversationId: conversationId,
                otherUserId: otherUserId,
                otherUserName: otherUserName,
                otherUserPhoto: otherUserPhoto,
              ),
            ),
          );
        },
      ),
    );
  }

  void _openChat(Conversation conversation) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversationId: conversation.id,
          otherUserName: conversation.getOtherParticipantName(currentUserId),
          otherUserPhoto: conversation.getOtherParticipantPhoto(currentUserId),
          otherUserId: conversation.getOtherParticipantId(currentUserId),
        ),
      ),
    );
  }

  void _showConversationOptions(Conversation conversation) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: Text('View ${conversation.getOtherParticipantName(currentUserId)}\'s profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to profile
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete conversation', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(conversation);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Conversation conversation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _dmService.deleteConversation(conversation.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Conversation deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── New Message Bottom Sheet ────────────────────────────────────────────────

class _NewMessageSheet extends StatefulWidget {
  final String currentUserId;
  final DmService dmService;
  final void Function(
    String conversationId,
    String otherUserId,
    String otherUserName,
    String? otherUserPhoto,
  ) onConversationOpened;

  const _NewMessageSheet({
    required this.currentUserId,
    required this.dmService,
    required this.onConversationOpened,
  });

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  final TextEditingController _controller = TextEditingController();
  final SearchService _searchService = SearchService();
  Timer? _debounce;

  List<SearchResult> _results = [];
  bool _isSearching = false;
  String? _loadingUserId;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() { _results = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await _searchService.searchUsers(query.trim());
      // Exclude the current user from results
      final filtered = results.where((r) => r.id != widget.currentUserId).toList();
      if (mounted) setState(() { _results = filtered; _isSearching = false; });
    });
  }

  Future<void> _startChat(SearchResult user) async {
    if (_loadingUserId != null) return;
    setState(() => _loadingUserId = user.id);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final otherUserName = user.title;
      final otherUserPhoto = user.imageUrl;

      // Fetch current user's display name from Firestore for accuracy
      String currentUserName = currentUser?.displayName ?? 'Runner';
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUserId)
            .get();
        currentUserName = doc.data()?['displayName'] as String? ?? currentUserName;
      } catch (e) {
        debugPrint('⚠️ ConversationsListScreen: failed to fetch display name, using fallback: $e');
      }

      final conversationId = await widget.dmService.getOrCreateConversation(
        currentUserId: widget.currentUserId,
        otherUserId: user.id,
        currentUserName: currentUserName,
        otherUserName: otherUserName,
        currentUserPhoto: currentUser?.photoURL,
        otherUserPhoto: otherUserPhoto,
      );

      if (conversationId != null && mounted) {
        widget.onConversationOpened(
          conversationId,
          user.id,
          otherUserName,
          otherUserPhoto,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open conversation: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Text(
                  'New Message',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search runners...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF00E676)),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Results
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: _buildResults(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF00E676), strokeWidth: 2)),
      );
    }
    if (_controller.text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search, size: 40, color: Colors.grey[300]),
              const SizedBox(height: 8),
              Text('Search for a runner to message',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ],
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('No users found',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final user = _results[i];
        final isLoading = _loadingUserId == user.id;
        return ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey[200],
            backgroundImage: (user.imageUrl != null && user.imageUrl!.isNotEmpty)
                ? NetworkImage(user.imageUrl!)
                : null,
            child: (user.imageUrl == null || user.imageUrl!.isEmpty)
                ? const Icon(Icons.person, color: Colors.grey, size: 22)
                : null,
          ),
          title: Text(user.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: user.subtitle.isNotEmpty
              ? Text(user.subtitle,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12))
              : null,
          trailing: isLoading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E676)),
                )
              : const Icon(Icons.send_rounded, color: Color(0xFF00E676), size: 20),
          onTap: () => _startChat(user),
        );
      },
    );
  }
}
