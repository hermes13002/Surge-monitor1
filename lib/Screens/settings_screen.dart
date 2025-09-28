import 'package:flutter/material.dart';
// import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.onLogout,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    // final info = await PackageInfo.fromPlatform();
    // setState(() {
    //   _version = '${info.version}+${info.buildNumber}';
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text('Dark Mode'),
            value: widget.isDarkMode,
            onChanged: widget.onThemeChanged,
          ),
          ListTile(
            title: Text('App Version'),
            subtitle: Text(_version.isEmpty ? 'Loading...' : _version),
          ),
          ListTile(
            title: Text('Logout'),
            leading: Icon(Icons.logout),
            onTap: widget.onLogout,
          ),
        ],
      ),
    );
  }
}
