import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../auth/domain/repositories/auth_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // TOP NAVIGATION (Blueprint: Profile, Search, Notification, Messages)
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.account_circle_outlined), // Profile Icon
          onPressed: () {},
        ),
        title: IconButton(
          icon: const Icon(Icons.search), // Search Symbol
          onPressed: () {},
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none), // Notification Bell
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline), // Messages Symbols
            onPressed: () {},
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),

      // CENTER CONTENT (Blueprint: Posts or Feed)
      body: ListView.builder(
        itemCount: 10,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.all(10),
            child: Container(
              height: 200,
              alignment: Alignment.center,
              child: Text("Post or Feed Item #$index"),
            ),
          );
        },
      ),

      // BOTTOM NAVIGATION (Blueprint: home, Workouts, Create, Events, RUN)
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'home'),
          BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Workouts'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box_outlined), label: 'Create'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_run), label: 'RUN'),
        ],
      ),
    );
  }
}