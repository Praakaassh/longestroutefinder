import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Make sure you have this file for the map page.
import 'package:tinderprojecthub/Home/mappage.dart';


// Placeholder for your Scoreboard Page. Create this file or replace the widget.
class ScoreboardPage extends StatelessWidget {
  const ScoreboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Scoreboard Page', style: TextStyle(color: Colors.white, fontSize: 18)),
    );
  }
}

// ------------------- Main Home Page Widget -------------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // List of pages to navigate between
  final List<Widget> _pages = [
    const HomeContent(),
    const MapPage(),
    const ScoreboardPage(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      await _googleSignIn.signOut();
      if (mounted) {
        // Navigate to your signup or login screen.
        // Make sure you have a '/signup' route in your main.dart
        Navigator.pushReplacementNamed(context, '/signup');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark background color
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              // Custom Header
              _buildAppBar(context),
              const SizedBox(height: 24),
              // Custom Tab Bar
              _buildTabBar(),
              const SizedBox(height: 24),
              // Page Content
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the custom header/app bar.
  Widget _buildAppBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Longest Route',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          onPressed: () => _signOut(context),
          icon: const Icon(Icons.exit_to_app, color: Colors.white),
        ),
      ],
    );
  }

  /// Builds the custom tab bar for navigation.
  Widget _buildTabBar() {
    return Row(
      children: [
        _buildTabItem('Home', 0),
        const SizedBox(width: 16),
        _buildTabItem('Map', 1),
        const SizedBox(width: 16),
        _buildTabItem('Scoreboard', 2),
      ],
    );
  }

  /// Builds a single tab item.
  Widget _buildTabItem(String title, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB5FF42) : Colors.grey[850],
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ------------------- Content for the Home Tab -------------------

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the current user from Firebase Auth to display their info
    final user = FirebaseAuth.instance.currentUser;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Profile Section ---
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey[800],
                  // Use a placeholder if the user image is null
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                  // A default icon as a placeholder
                      ? const Icon(Icons.person, size: 45, color: Colors.white70)
                      : null,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Welcome back!',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.displayName ?? 'Subinraj', // Display user's name or a default
                  style: const TextStyle(color: Color(0xFFB5FF42), fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // --- Stats Section ---
          const Text(
            'Your Stats',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 30),

          // --- Recent Activity Section ---
          const Text(
            'Recent Activity',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildActivityItem(),
          // You can add more activity items here if needed
        ],
      ),
    );
  }

  /// Builds the row of stat cards.
  Widget _buildStatsRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatCard('Total Score', '12,500'),
          const SizedBox(width: 12),
          _buildStatCard('Time Traveled', '32h 15m'),
          const SizedBox(width: 12),
          _buildStatCard('Routes Completed', '7'),
        ],
      ),
    );
  }


  /// Builds a card for the stats grid.
  Widget _buildStatCard(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single item for the recent activity list.
  Widget _buildActivityItem() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle, color: Color(0xFFB5FF42)),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'You leveled up to the Pacific Crest!',
              style: TextStyle(color: Colors.white, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}