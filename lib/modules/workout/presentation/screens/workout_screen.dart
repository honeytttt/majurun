import 'package:flutter/material.dart';

class WorkoutScreen extends StatelessWidget {
  const WorkoutScreen({super.key});

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
              _buildFeaturedCard(brandGreen),
              const SizedBox(height: 30),
              _buildSectionTitle("AI SPECIALIZED COACHES"),
              const SizedBox(height: 15),
              _buildWorkoutGrid(),
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
        Text("CHOOSE YOUR", 
          style: TextStyle(fontSize: 12, color: brandGreen, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const Text("WORKOUT HUB", 
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildFeaturedCard(Color brandGreen) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        gradient: LinearGradient(
          colors: [Colors.black.withOpacity(0.8), Colors.black.withOpacity(0.6)],
        ),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1517836357463-d25dfeac3438?w=800'),
          fit: BoxFit.cover,
          opacity: 0.6,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: brandGreen, borderRadius: BorderRadius.circular(8)),
              child: const Text("RECOMMENDED", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            const Text("Pre-Run Activation", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const Text("AI-Guided • 8 Mins", style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, 
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.0));
  }

  Widget _buildWorkoutGrid() {
    final List<Map<String, String>> coaches = [
      {"name": "Six Pack AI", "icon": "🔥", "label": "Abdominals"},
      {"name": "Calisthenics", "icon": "💪", "label": "Bodyweight"},
      {"name": "Yoga Coach", "icon": "🧘", "label": "Flexibility"},
      {"name": "HIIT Master", "icon": "⚡", "label": "High Intensity"},
      {"name": "Swimming AI", "icon": "🏊", "label": "Endurance"},
      {"name": "Meditation", "icon": "🧠", "label": "Mental Health"},
      {"name": "Home Workouts", "icon": "🏠", "label": "No Equipment"},
      {"name": "Outdoor Pro", "icon": "🌲", "label": "Nature Training"},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.1,
      ),
      itemCount: coaches.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(coaches[index]["icon"]!, style: const TextStyle(fontSize: 30)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(coaches[index]["name"]!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(coaches[index]["label"]!, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}