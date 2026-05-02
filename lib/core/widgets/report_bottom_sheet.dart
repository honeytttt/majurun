import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:majurun/core/services/report_service.dart';

enum _ReportTarget { post, user, message }

/// Shows a bottom sheet that lets the current user report a post, user, or
/// message. Call the static helpers below — they handle routing internally.
class ReportBottomSheet extends StatefulWidget {
  final _ReportTarget _target;
  final String targetId;
  final String? targetOwnerId;
  final String? conversationId;

  const ReportBottomSheet._({
    required _ReportTarget target,
    required this.targetId,
    this.targetOwnerId,
    this.conversationId,
  }) : _target = target;

  /// Report a post.
  static Future<void> showForPost(
    BuildContext context, {
    required String postId,
    required String postOwnerId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReportBottomSheet._(
        target: _ReportTarget.post,
        targetId: postId,
        targetOwnerId: postOwnerId,
      ),
    );
  }

  /// Report a user.
  static Future<void> showForUser(
    BuildContext context, {
    required String userId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReportBottomSheet._(
        target: _ReportTarget.user,
        targetId: userId,
      ),
    );
  }

  /// Report a message in a DM conversation.
  static Future<void> showForMessage(
    BuildContext context, {
    required String messageId,
    required String conversationId,
    required String senderId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReportBottomSheet._(
        target: _ReportTarget.message,
        targetId: messageId,
        targetOwnerId: senderId,
        conversationId: conversationId,
      ),
    );
  }

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  static const _reasons = [
    'Spam or misleading',
    'Harassment or bullying',
    'Inappropriate content',
    'Fake account',
    'Violence or dangerous activity',
    'Other',
  ];

  String? _selectedReason;
  bool _submitting = false;

  String get _title {
    switch (widget._target) {
      case _ReportTarget.post:
        return 'Report Post';
      case _ReportTarget.user:
        return 'Report User';
      case _ReportTarget.message:
        return 'Report Message';
    }
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    final reporterId = FirebaseAuth.instance.currentUser?.uid;
    if (reporterId == null) return;

    setState(() => _submitting = true);

    try {
      final svc = ReportService();
      switch (widget._target) {
        case _ReportTarget.post:
          await svc.reportPost(
            reporterId: reporterId,
            postId: widget.targetId,
            postOwnerId: widget.targetOwnerId ?? '',
            reason: _selectedReason!,
          );
          break;
        case _ReportTarget.user:
          await svc.reportUser(
            reporterId: reporterId,
            reportedUserId: widget.targetId,
            reason: _selectedReason!,
          );
          break;
        case _ReportTarget.message:
          await svc.reportMessage(
            reporterId: reporterId,
            messageId: widget.targetId,
            conversationId: widget.conversationId ?? '',
            senderId: widget.targetOwnerId ?? '',
            reason: _selectedReason!,
          );
          break;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted — thank you for keeping MajuRun safe.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to submit report. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              _title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Why are you reporting this?',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          const Divider(height: 1),
          RadioGroup<String>(
            groupValue: _selectedReason,
            onChanged: (v) => setState(() => _selectedReason = v),
            child: Column(
              children: _reasons.map((reason) => RadioListTile<String>(
                    value: reason,
                    title: Text(reason),
                    activeColor: const Color(0xFF00E676),
                  )).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedReason == null || _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Text('Submit Report', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
