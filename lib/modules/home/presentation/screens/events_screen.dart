// @UI_LOCK: Finalized Community & Rewards Layout - 2026-01-25
// -----------------------------------------------------------------------
// FIX: Removed invalid 'const' keywords from rows using .withValues()
// -----------------------------------------------------------------------

import 'package:flutter/material.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF00E676);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(brandGreen),
              const SizedBox(height: 25),
              _buildActiveChallenge(brandGreen),
              const SizedBox(height: 30),
              _buildSectionTitle("UPCOMING MEETUPS"),
              const SizedBox(height: 15),
              _buildMeetupList(brandGreen),
              const SizedBox(height: 30),
              _buildSectionTitle("TOP PERFORMERS THIS WEEK"),
              const SizedBox(height: 15),
              _buildLeaderboard(),
              const SizedBox(height: 30),
              _buildSectionTitle("YOUR REWARDS & BADGES"),
              const SizedBox(height: 15),
              _buildRewardsGallery(brandGreen),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color brandGreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("JOIN THE", 
          style: TextStyle(fontSize: 12, color: brandGreen, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const Text("COMMUNITY", 
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildActiveChallenge(Color brandGreen) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: brandGreen.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("MONTHLY CHALLENGE", 
                style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              Icon(Icons.emoji_events_rounded, color: brandGreen, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          const Text("January 50KM Sprint", 
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          LinearProgressIndicator(
            value: 0.65,
            backgroundColor: Colors.white12,
            color: brandGreen,
            borderRadius: BorderRadius.circular(10),
            minHeight: 8,
          ),
          const SizedBox(height: 10),
          // REMOVED 'const' FROM ROW BELOW
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("32.5 / 50 KM", style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text("65%", style: TextStyle(color: brandGreen, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, 
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0));
  }

  Widget _buildMeetupList(Color brandGreen) {
    final List<Map<String, String>> meetups = [
      {"title": "City Center 5K", "date": "SAT, 08:00 AM", "joined": "24 joined", "icon": "🏃"},
      {"title": "Yoga in the Park", "date": "SUN, 09:30 AM", "joined": "12 joined", "icon": "🧘"},
    ];

    return Column(
      children: meetups.map((event) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              height: 50, width: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5)]
              ),
              child: Center(child: Text(event["icon"]!, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event["title"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(event["date"]!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: brandGreen,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text("JOIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            )
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildLeaderboard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Column(
        children: List.generate(3, (index) => ListTile(
          leading: Container(
            width: 35, height: 35,
            decoration: BoxDecoration(
              color: index == 0 ? const Color(0xFFFFD700).withValues(alpha: 0.2) : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text("${index + 1}", 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: index == 0 ? const Color(0xFFB8860B) : Colors.black
                )
              ),
            ),
          ),
          title: Text(["Alex Rivera", "Sarah Chen", "Mike Ross"][index], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("${[142.5, 128.2, 115.0][index]} KM this month"),
          trailing: const Icon(Icons.stars_rounded, color: Colors.orange, size: 20),
        )),
      ),
    );
  }

  Widget _buildRewardsGallery(Color brandGreen) {
    final List<Map<String, dynamic>> badges = [
      {"name": "Early Bird", "icon": "🌅", "locked": false},
      {"name": "50K Club", "icon": "🎖️", "locked": false},
      {"name": "Mountain King", "icon": "🏔️", "locked": true},
      {"name": "Yoga Zen", "icon": "☯️", "locked": true},
    ];

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: badges.length,
        itemBuilder: (context, index) {
          final badge = badges[index];
          return Container(
            width: 85,
            margin: const EdgeInsets.only(right: 15),
            decoration: BoxDecoration(
              color: badge["locked"] ? Colors.grey[50] : brandGreen.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: badge["locked"] ? Colors.grey[200]! : brandGreen.withValues(alpha: 0.3)
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: badge["locked"] ? 0.3 : 1.0,
                  child: Text(badge["icon"], style: const TextStyle(fontSize: 30)),
                ),
                const SizedBox(height: 5),
                Text(
                  badge["name"], 
                  style: TextStyle(
                    fontSize: 10, 
                    fontWeight: FontWeight.bold,
                    color: badge["locked"] ? Colors.grey : Colors.black
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}