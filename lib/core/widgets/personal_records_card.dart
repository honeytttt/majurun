import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:majurun/core/services/personal_records_service.dart';

/// Personal Records Display Card
/// Shows user's best running achievements
class PersonalRecordsCard extends StatefulWidget {
  const PersonalRecordsCard({super.key});

  @override
  State<PersonalRecordsCard> createState() => _PersonalRecordsCardState();
}

class _PersonalRecordsCardState extends State<PersonalRecordsCard> {
  late PersonalRecordsService _prService;

  @override
  void initState() {
    super.initState();
    _prService = PersonalRecordsService();
    _prService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _prService,
      child: Consumer<PersonalRecordsService>(
        builder: (context, prService, child) {
          if (prService.isLoading) {
            return _buildLoadingCard();
          }

          final records = prService.records;
          if (records == null) {
            return _buildEmptyCard();
          }

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal Records',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Your best achievements',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Records Grid
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildRecordItem(
                              icon: '📏',
                              label: 'Longest Run',
                              value: records.longestDistanceKm != null
                                  ? '${records.longestDistanceKm!.toStringAsFixed(2)} km'
                                  : '--',
                              date: records.longestDistanceDate,
                              color: const Color(0xFF00E676),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRecordItem(
                              icon: '⚡',
                              label: 'Fastest Pace',
                              value: records.fastestPaceSecPerKm != null
                                  ? PersonalRecordsService.formatPace(
                                      records.fastestPaceSecPerKm!)
                                  : '--',
                              date: records.fastestPaceDate,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRecordItem(
                              icon: '🥇',
                              label: 'Fastest 1K',
                              value: records.fastest1kSeconds != null
                                  ? PersonalRecordsService.formatTime(
                                      records.fastest1kSeconds!)
                                  : '--',
                              date: records.fastest1kDate,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRecordItem(
                              icon: '🏃',
                              label: 'Fastest 5K',
                              value: records.fastest5kSeconds != null
                                  ? PersonalRecordsService.formatTime(
                                      records.fastest5kSeconds!)
                                  : '--',
                              date: records.fastest5kDate,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildRecordItem(
                              icon: '🏅',
                              label: 'Fastest 10K',
                              value: records.fastest10kSeconds != null
                                  ? PersonalRecordsService.formatTime(
                                      records.fastest10kSeconds!)
                                  : '--',
                              date: records.fastest10kDate,
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildRecordItem(
                              icon: '⏱️',
                              label: 'Longest Time',
                              value: records.longestDurationSeconds != null
                                  ? PersonalRecordsService.formatTime(
                                      records.longestDurationSeconds!.toDouble())
                                  : '--',
                              date: records.longestDurationDate,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFFFD700),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.emoji_events_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No records yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete runs to set your personal bests!',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem({
    required String icon,
    required String label,
    required String value,
    required DateTime? date,
    required Color color,
  }) {
    final hasValue = value != '--';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasValue
            ? color.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasValue
              ? color.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: hasValue ? color : Colors.grey[400],
            ),
          ),
          if (date != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM d, yyyy').format(date),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// PR Celebration Dialog
/// Shown when user achieves a new personal record
class PRCelebrationDialog extends StatelessWidget {
  final List<PRUpdate> newRecords;

  const PRCelebrationDialog({super.key, required this.newRecords});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Celebration icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.emoji_events,
                color: Colors.white,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'New Personal Record!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You crushed it!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // PR list
            ...newRecords.map((pr) => _buildPRItem(pr)),

            const SizedBox(height: 24),

            // Close button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Awesome!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPRItem(PRUpdate pr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Text(
            pr.icon,
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pr.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatPRValue(pr),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB8860B),
                  ),
                ),
              ],
            ),
          ),
          if (pr.oldValue != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_upward,
                    color: Color(0xFF00E676),
                    size: 12,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'PR!',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatPRValue(PRUpdate pr) {
    switch (pr.type) {
      case PRType.longestDistance:
        return '${pr.newValue.toStringAsFixed(2)} km';
      case PRType.fastestPace:
        return PersonalRecordsService.formatPace(pr.newValue);
      case PRType.longestDuration:
      case PRType.fastest1K:
      case PRType.fastest5K:
      case PRType.fastest10K:
        return PersonalRecordsService.formatTime(pr.newValue);
      case PRType.highestElevation:
        return '${pr.newValue.toInt()} m';
    }
  }
}

/// Show PR celebration dialog
void showPRCelebration(BuildContext context, List<PRUpdate> newRecords) {
  if (newRecords.isEmpty) return;

  showDialog(
    context: context,
    builder: (context) => PRCelebrationDialog(newRecords: newRecords),
  );
}
