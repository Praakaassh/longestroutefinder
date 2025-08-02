import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tinderprojecthub/Home/settings.dart';

import 'mappage.dart';

// A placeholder widget for the Profile page to prevent errors
class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Profile Page', style: TextStyle(fontSize: 24)),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  int _selectedIndex = 0;
  late PageController _pageController; // Controller for the PageView

  // List of pages for navigation (Added ProfilePage)
  final List<Widget> _pages = [
    HomeContent(),
    MapPage(),
    SettingsPage(),
    ProfilePage(), // Added page for the profile icon
  ];

  @override
  void initState() {
    super.initState();
    // Initialize the controller with the starting page index
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is removed
    _pageController.dispose();
    super.dispose();
  }

  // This function now animates the PageView to the new page
  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _signOut(context),
            icon: Icon(Icons.logout),
          ),
        ],
      ),
      // Use PageView to enable swiping
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          // Update the selected index when the user swipes
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages,
      ),
      // Removed the notch properties from BottomAppBar
      bottomNavigationBar: BottomAppBar(
        child: Container(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.map, 'Map', 1),
              _buildNavItem(Icons.settings, 'Settings', 2),
              _buildNavItem(Icons.person, 'Profile', 3),
            ],
          ),
        ),
      ),
      // REMOVED FloatingActionButton and its location
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        // Using Expanded to ensure items share space equally
        // This is another way to prevent overflow issues
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.blue : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Home';
      case 1:
        return 'Map';
      case 2:
        return 'Settings';
      case 3:
        return 'Profile'; // Added title for Profile page
      default:
        return 'Home';
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      await _googleSignIn.signOut();
      Navigator.pushReplacementNamed(context, '/signup');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
}


// Home Content Widget (your original home page content)
class HomeContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // User Avatar
            CircleAvatar(
              radius: 50,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Icon(Icons.person, size: 50)
                  : null,
            ),

            SizedBox(height: 20),

            // Welcome Message
            Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 10),

            // User Name
            Text(
              user?.displayName ?? 'User',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[600],
              ),
            ),

            SizedBox(height: 10),

            // User Email
            Text(
              user?.email ?? 'No email',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),

            SizedBox(height: 40),

            // Quick Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAction(Icons.map, 'View Map', () {
                  // You can add navigation logic here if needed,
                  // but swiping and tapping the bottom bar already works.
                }),
                _buildQuickAction(Icons.settings, 'Settings', () {
                  // Handle settings action
                }),
                _buildQuickAction(Icons.notification_add, 'Notifications', () {
                  // Handle notifications
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.blue, size: 30),
          ),
          SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}