import 'package:flutter/material.dart';
import 'package:surge_monitor/Screens/home_screen';
import 'package:surge_monitor/Screens/logs_screen.dart'; // Create this file for your logs screen
import 'package:surge_monitor/Screens/settings_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Surge Monitor",
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  bool _isDarkMode = false;

  void _onThemeChanged(bool value) {
    setState(() {
      _isDarkMode = value;
    });
  }

  void _logout() {
    // Add your logout logic here
    // For now, just show a dialog
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text('Logged out'),
            content: Text('You have been logged out.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(),
      LogsScreen(),
      SettingsScreen(
        isDarkMode: _isDarkMode,
        onThemeChanged: _onThemeChanged,
        onLogout: _logout,
      ),
    ];

    return MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: screens[_selectedIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home, color: Colors.blue,), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.list, color: Colors.blue), label: 'Logs'),
            BottomNavigationBarItem(icon: Icon(Icons.settings, color: Colors.blue), label: 'Settings',),
          ],
        ),
      ),
    );
  }
}
