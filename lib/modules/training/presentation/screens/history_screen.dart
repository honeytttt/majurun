import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:majurun/core/widgets/shimmer_loader.dart';
import 'package:majurun/core/widgets/empty_state_widget.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback onBack; // callback to return to main menu
  const HistoryScreen({super.key, required this.onBack});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  String _formatTimeRange(DateTime endTime, int? durationSeconds) {
    // ✅ Professional time range display
    // end: completedAt
    // start: end - durationSeconds
    final startTime = (durationSeconds != null && durationSeconds > 0)
        ? endTime.subtract(Duration(seconds: durationSeconds))
        : endTime;

    final datePart = DateFormat('MMM dd').format(endTime);
    final start = DateFormat('HH:mm').format(startTime);
    final end = DateFormat('HH:mm').format(endTime);

    // If duration missing, still show single time (clean)
    if (durationSeconds == null || durationSeconds <= 0) {
      return "$datePart • $end";
    }
    return "$datePart • $start–$end";
  }

  // Small helper: safe Timestamp -> DateTime
  DateTime? _asDateTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  int? _asNullableInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    return _asNullableInt(v) ?? fallback;
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 20),
                onPressed: widget.onBack,
              ),
              const Text(
                "WORKOUT CALENDAR",
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
            ],
          ),
        ),

        TableCalendar(
          firstDay: DateTime.utc(2024, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
            selectedDecoration: BoxDecoration(color: Colors.black, shape: BoxShape.circle),
          ),
        ),

        const Divider(),

        Expanded(
          child: (userId == null || userId.isEmpty)
              ? ListView.builder(
                  itemCount: 5,
                  itemBuilder: (_, __) => ShimmerLoader.runTileSkeleton(),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('training_history')
                      .orderBy('completedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Center(child: Text('Failed to load sessions.'));
                    if (!snapshot.hasData) {
                      return ListView.builder(
                        itemCount: 5,
                        itemBuilder: (_, __) => ShimmerLoader.runTileSkeleton(),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    final filteredDocs = _selectedDay == null
                        ? docs
                        : docs.where((doc) {
                            final rawCompleted = (doc.data() as Map<String, dynamic>)['completedAt'];
                            final date = _asDateTime(rawCompleted);
                            if (date == null) return false;
                            return isSameDay(date, _selectedDay);
                          }).toList();

                    if (filteredDocs.isEmpty) {
                      return const EmptyStateWidget(
                        icon: Icons.fitness_center_outlined,
                        title: 'No sessions yet',
                        subtitle: 'Complete a training session to see your history here.',
                      );
                    }

                    return ListView.builder(
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final data = filteredDocs[index].data() as Map<String, dynamic>;

                        final planTitle = (data['planTitle'] ?? 'Session').toString();
                        final week = _asInt(data['week'], fallback: 0);
                        final day = _asInt(data['day'], fallback: 0);

                        final completedAt = _asDateTime(data['completedAt']) ?? DateTime.now();

                        final durationSeconds = _asNullableInt(data['durationSeconds']);
                        final timeRange = _formatTimeRange(completedAt, durationSeconds);

                        // ✅ map/plan preview support
                        final String? mapImageUrl = data['mapImageUrl']?.toString();
                        final bool hasImage = mapImageUrl != null && mapImageUrl.isNotEmpty;

                        return ListTile(
                          leading: hasImage
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    mapImageUrl, // ✅ no "!" (removes unnecessary_non_null_assertion) [1](https://necms-my.sharepoint.com/personal/hanumaiah_ta_nec_com_sg/Documents/Microsoft%20Copilot%20Chat%20Files/feb6.txt)
                                    width: 46,
                                    height: 46,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const CircleAvatar(
                                        backgroundColor: Colors.blue,
                                        child: Icon(Icons.bolt, color: Colors.white),
                                      );
                                    },
                                  ),
                                )
                              : const CircleAvatar(
                                  backgroundColor: Colors.blue,
                                  child: Icon(Icons.bolt, color: Colors.white),
                                ),

                          title: Text(planTitle),

                          // ✅ Professional subtitle
                          subtitle: Text(
                            "Wk $week • Day $day  •  $timeRange",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          // Keep trailing as date (clean)
                          trailing: Text(DateFormat('yyyy-MM-dd').format(completedAt)),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}