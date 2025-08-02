import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _locationEnabled = true;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Padding(
      padding: EdgeInsets.all(16.0),
      child: ListView(
        children: [
          // User Profile Section
          Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Icon(Icons.person, size: 30)
                        : null,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'User',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          user?.email ?? 'No email',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Edit profile
                      _showEditProfileDialog();
                    },
                    icon: Icon(Icons.edit),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Settings Options
          Text(
            'Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 10),

          _buildSettingsTile(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Enable push notifications',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
          ),

          _buildSettingsTile(
            icon: Icons.dark_mode,
            title: 'Dark Mode',
            subtitle: 'Enable dark theme',
            trailing: Switch(
              value: _darkModeEnabled,
              onChanged: (value) {
                setState(() {
                  _darkModeEnabled = value;
                });
              },
            ),
          ),

          _buildSettingsTile(
            icon: Icons.location_on,
            title: 'Location Services',
            subtitle: 'Allow location access',
            trailing: Switch(
              value: _locationEnabled,
              onChanged: (value) {
                setState(() {
                  _locationEnabled = value;
                });
              },
            ),
          ),

          SizedBox(height: 20),

          Text(
            'Account',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 10),

          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to privacy policy
            },
          ),

          _buildSettingsTile(
            icon: Icons.help,
            title: 'Help & Support',
            subtitle: 'Get help and support',
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              // Navigate to help page
            },
          ),

          _buildSettingsTile(
            icon: Icons.info,
            title: 'About',
            subtitle: 'App version and info',
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: () {
              _showAboutDialog();
            },
          ),

          SizedBox(height: 30),

          // Sign Out Button
          ElevatedButton.icon(
            onPressed: () => _signOut(context),
            icon: Icon(Icons.logout),
            label: Text('Sign Out'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Colors.blue),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Profile'),
        content: Text('Profile editing functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('App Version: 1.0.0'),
            Text('Built with Flutter'),
            Text('Firebase Authentication'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacementNamed(context, '/signup');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }
  }
}
