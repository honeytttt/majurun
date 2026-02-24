import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:majurun/core/services/dm_service.dart';
import 'package:majurun/modules/dm/domain/entities/user_privacy.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final DmService _dmService = DmService();
  UserPrivacy? _privacy;
  bool _isLoading = true;
  MessagePrivacy? _selectedPrivacy;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        Navigator.pop(context);
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('userPrivacy')
          .doc(userId)
          .get();

      if (doc.exists) {
        _privacy = UserPrivacy.fromFirestore(doc.data()!, userId);
      } else {
        _privacy = UserPrivacy(userId: userId);
        await _dmService.updatePrivacySettings(userId, _privacy!);
      }
      _selectedPrivacy = _privacy?.messagePrivacy;
    } catch (e) {
      debugPrint('❌ Error loading privacy settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_privacy == null) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await _dmService.updatePrivacySettings(userId, _privacy!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Privacy settings saved'),
            backgroundColor: Color(0xFF00E676),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving privacy settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updatePrivacy(MessagePrivacy newValue) {
    setState(() {
      _selectedPrivacy = newValue;
      if (_privacy != null) {
        _privacy = UserPrivacy(
          userId: _privacy!.userId,
          messagePrivacy: newValue,
          showReadReceipts: _privacy!.showReadReceipts,
          showTypingIndicator: _privacy!.showTypingIndicator,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          'Privacy Settings',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saveSettings,
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF00E676),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : ListView(
              children: [
                const SizedBox(height: 16),
                _buildSection(
                  'Message Privacy',
                  _buildPrivacyOptions(),
                ),
                _buildSection(
                  'Read Receipts',
                  [
                    _buildReadReceiptsSwitch(),
                  ],
                ),
                _buildSection(
                  'Typing Indicator',
                  [
                    _buildTypingIndicatorSwitch(),
                  ],
                ),
                _buildBlockedUsersList(),
              ],
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        ...children,
        const Divider(height: 32),
      ],
    );
  }

  List<Widget> _buildPrivacyOptions() {
    return [
      _buildRadioTile(
        'Everyone',
        'Anyone can message you',
        MessagePrivacy.everyone,
      ),
      _buildRadioTile(
        'Followers Only',
        'Only people you follow can message you',
        MessagePrivacy.followersOnly,
      ),
      _buildRadioTile(
        'No One',
        'No one can message you',
        MessagePrivacy.noOne,
      ),
    ];
  }

  // ✅ FIXED: Using ListTile with Radio instead of deprecated RadioListTile
  Widget _buildRadioTile(String title, String subtitle, MessagePrivacy value) {
    return ListTile(
      leading: Radio<MessagePrivacy>(
        value: value,
        groupValue: _selectedPrivacy,
        onChanged: (newValue) {
          if (newValue != null) {
            _updatePrivacy(newValue);
          }
        },
        activeColor: const Color(0xFF00E676),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle),
      onTap: () => _updatePrivacy(value),
    );
  }

  Widget _buildReadReceiptsSwitch() {
    return SwitchListTile(
      title: const Text(
        'Show read receipts',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: const Text('Let others know when you\'ve read their messages'),
      value: _privacy?.showReadReceipts ?? true,
      onChanged: (value) {
        setState(() {
          if (_privacy != null) {
            _privacy = UserPrivacy(
              userId: _privacy!.userId,
              messagePrivacy: _privacy!.messagePrivacy,
              showReadReceipts: value,
              showTypingIndicator: _privacy!.showTypingIndicator,
            );
          }
        });
      },
      activeTrackColor: const Color(0xFF00E676).withValues(alpha: 0.5),
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF00E676);
        }
        return Colors.grey;
      }),
    );
  }

  Widget _buildTypingIndicatorSwitch() {
    return SwitchListTile(
      title: const Text(
        'Show typing indicator',
        style: TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: const Text('Let others know when you\'re typing'),
      value: _privacy?.showTypingIndicator ?? true,
      onChanged: (value) {
        setState(() {
          if (_privacy != null) {
            _privacy = UserPrivacy(
              userId: _privacy!.userId,
              messagePrivacy: _privacy!.messagePrivacy,
              showReadReceipts: _privacy!.showReadReceipts,
              showTypingIndicator: value,
            );
          }
        });
      },
      activeTrackColor: const Color(0xFF00E676).withValues(alpha: 0.5),
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xFF00E676);
        }
        return Colors.grey;
      }),
    );
  }

  Widget _buildBlockedUsersList() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Blocked Users',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('blockedUsers')
              .orderBy('blockedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
              );
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No blocked users',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    backgroundImage: data['blockedUserPhoto'] != null
                        ? CachedNetworkImageProvider(data['blockedUserPhoto'])
                        : null,
                    child: data['blockedUserPhoto'] == null
                        ? Icon(Icons.person, color: Colors.grey[400])
                        : null,
                  ),
                  title: Text(
                    data['blockedUserName'] ?? 'Unknown User',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Blocked ${_formatDate((data['blockedAt'] as Timestamp?)?.toDate())}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  trailing: TextButton(
                    onPressed: () => _unblockUser(doc.id, data['blockedUserName'] ?? 'user'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF00E676),
                    ),
                    child: const Text('Unblock'),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'recently';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 30) {
      return '${difference.inDays ~/ 30} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return 'recently';
    }
  }

  Future<void> _unblockUser(String blockedUserId, String userName) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await _dmService.unblockUser(userId, blockedUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName has been unblocked'),
            backgroundColor: const Color(0xFF00E676),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error unblocking user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unblocking user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}