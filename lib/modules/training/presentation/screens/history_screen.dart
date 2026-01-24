import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback onBack; // Added callback to return to main menu
  const HistoryScreen({super.key, required this.onBack});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Column( // REMOVED Scaffold
      children: [
        // Custom professional header for sub-page
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 20), 
                onPressed: widget.onBack
              ),
              const Text("WORKOUT CALENDAR", 
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
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
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .collection('training_history')
                .orderBy('completedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final docs = snapshot.data!.docs;
              final filteredDocs = _selectedDay == null
                ? docs
                : docs.where((doc) {
                    final date = (doc['completedAt'] as Timestamp).toDate();
                    return isSameDay(date, _selectedDay);
                  }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(child: Text("No runs recorded for this period."));
              }

              return ListView.builder(
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.bolt, color: Colors.white)),
                    title: Text(data['planTitle']),
                    subtitle: Text("Week ${data['week']} Day ${data['day']}"),
                    trailing: Text((data['completedAt'] as Timestamp).toDate().toString().split(' ')[0]),
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