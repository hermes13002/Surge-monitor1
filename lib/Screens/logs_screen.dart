import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  _LogsScreenState createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final DatabaseReference _logsRef = FirebaseDatabase.instance.ref().child("surges");
  final DatabaseReference _readingsRef = FirebaseDatabase.instance.ref().child("readings_history");
  final DatabaseReference _controlRef = FirebaseDatabase.instance.ref().child("device_control");

  bool _isLoadingSurges = true;
  bool _isLoadingReadings = true;
  List<Map<String, dynamic>> _surgeLogs = [];
  List<Map<String, dynamic>> _sensorHistory = [];
  List<Map<String, dynamic>> _controlLogs = [];

  @override
  void initState() {
    super.initState();
    _loadAllLogs();
  }

  Future<void> _loadAllLogs() async {
    await _loadSurgeLogs();
    await _loadSensorHistory();
    await _loadControlLogs();
  }

  Future<void> _loadSurgeLogs() async {
    try {
      DatabaseEvent event = await _logsRef.once();
      _processSurgeData(event.snapshot.value);
    } catch (e) {
      print('❌ Error loading surge logs: $e');
      setState(() {
        _isLoadingSurges = false;
      });
    }
  }

  Future<void> _loadSensorHistory() async {
    try {
      DatabaseEvent event = await _readingsRef.once();
      _processSensorData(event.snapshot.value);
    } catch (e) {
      print('❌ Error loading sensor history: $e');
      setState(() {
        _isLoadingReadings = false;
      });
    }
  }

  Future<void> _loadControlLogs() async {
    try {
      DatabaseEvent event = await _controlRef.once();
      _processControlData(event.snapshot.value);
    } catch (e) {
      print('❌ Error loading control logs: $e');
    }
  }

  void _processSurgeData(dynamic data) {
    if (data == null || data is! Map) {
      setState(() {
        _isLoadingSurges = false;
        _surgeLogs = [];
      });
      return;
    }

    List<Map<String, dynamic>> logs = [];

    data.forEach((key, value) {
      if (value is Map) {
        logs.add({
          'key': key,
          'timestamp': value['timestamp'] ?? 0,
          'voltage': (value['voltage'] as num?)?.toDouble() ?? 0.0,
          'current': (value['current'] as num?)?.toDouble() ?? 0.0,
          'status': value['status']?.toString() ?? 'Unknown',
          'power': (value['power'] as num?)?.toDouble() ?? 0.0,
        });
      }
    });

    // Sort by timestamp (newest first)
    logs.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

    setState(() {
      _surgeLogs = logs;
      _isLoadingSurges = false;
    });
  }

  void _processSensorData(dynamic data) {
    if (data == null || data is! Map) {
      setState(() {
        _isLoadingReadings = false;
        _sensorHistory = [];
      });
      return;
    }

    List<Map<String, dynamic>> logs = [];

    data.forEach((key, value) {
      if (value is Map) {
        logs.add({
          'key': key,
          'timestamp': value['timestamp'] ?? 0,
          'voltage': (value['voltage'] as num?)?.toDouble() ?? 0.0,
          'current': (value['current'] as num?)?.toDouble() ?? 0.0,
          'power': (value['power'] as num?)?.toDouble() ?? 0.0,
          'status': value['status']?.toString() ?? 'Normal',
          'source': value['source']?.toString() ?? 'Grid',
          'fridge_on': value['fridge_on'] ?? false,
          'manual_override': value['manual_override'] ?? false,
        });
      }
    });

    // Sort by timestamp (newest first)
    logs.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

    setState(() {
      _sensorHistory = logs;
      _isLoadingReadings = false;
    });
  }

  void _processControlData(dynamic data) {
    if (data == null || data is! Map) return;

    List<Map<String, dynamic>> logs = [];

    void processControlSection(String section, Map<dynamic, dynamic>? sectionData) {
      if (sectionData == null) return;

      sectionData.forEach((key, value) {
        if (value is Map) {
          logs.add({
            'type': 'control',
            'section': section,
            'key': key,
            'timestamp': value['timestamp'] ?? 0,
            'status': value['status'] ?? 'Unknown',
            'command_by': value['command_by'] ?? 'Unknown',
            'manual_override': value['manual_override'] ?? false,
          });
        }
      });
    }

    processControlSection('changeover', data['changeover']);
    processControlSection('fridge', data['fridge']);

    // Sort by timestamp (newest first)
    logs.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

    setState(() {
      _controlLogs = logs;
    });
  }

  String _formatTimestamp(int timestamp) {
    if (timestamp == 0) return 'Unknown time';

    try {
      var date = DateTime.fromMillisecondsSinceEpoch(timestamp);

      // Manual date formatting without intl package
      final month = _getMonthAbbreviation(date.month);
      final day = date.day.toString().padLeft(2, '0');
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      final second = date.second.toString().padLeft(2, '0');

      return '$month $day, $hour:$minute:$second';
    } catch (e) {
      return 'Invalid time';
    }
  }

  String _getMonthAbbreviation(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatTimeAgo(int timestamp) {
    if (timestamp == 0) return 'Unknown';

    try {
      var date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      var now = DateTime.now();
      var difference = now.difference(date);

      if (difference.inSeconds < 60) return '${difference.inSeconds}s ago';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 30) return '${difference.inDays}d ago';
      if (difference.inDays < 365) return '${(difference.inDays / 30).floor()}mo ago';
      return '${(difference.inDays / 365).floor()}y ago';
    } catch (e) {
      return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'danger':
      case 'surge_detected':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'normal':
        return Colors.green;
      case 'solar':
        return Colors.orange;
      case 'nepa':
        return Colors.blue;
      case 'on':
        return Colors.green;
      case 'off':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSurgeLogItem(Map<String, dynamic> log) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getStatusColor(log['status']).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            log['status'].toLowerCase().contains('danger') ? Icons.warning : Icons.warning_amber,
            color: _getStatusColor(log['status']),
            size: 24,
          ),
        ),
        title: Text(
          log['status'].replaceAll('_', ' '),
          style: GoogleFonts.ubuntu(
            fontWeight: FontWeight.w600,
            color: _getStatusColor(log['status']),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatTimeAgo(log['timestamp']),
              style: GoogleFonts.ubuntu(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildDataChip('${log['voltage'].toStringAsFixed(1)}V', Colors.orange),
                const SizedBox(width: 8),
                _buildDataChip('${log['current'].toStringAsFixed(2)}A', Colors.green),
                const SizedBox(width: 8),
                _buildDataChip('${log['power'].toStringAsFixed(1)}W', Colors.red),
              ],
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildSensorHistoryItem(Map<String, dynamic> reading) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            reading['source'] == "solar" ? Icons.solar_power : Icons.electrical_services,
            color: Colors.blue,
            size: 24,
          ),
        ),
        title: Row(
          children: [
            _buildDataChip('${reading['voltage'].toStringAsFixed(1)}V', Colors.orange),
            const SizedBox(width: 8),
            _buildDataChip('${reading['current'].toStringAsFixed(2)}A', Colors.green),
            const SizedBox(width: 8),
            _buildDataChip('${reading['power'].toStringAsFixed(1)}W', Colors.red),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              _formatTimeAgo(reading['timestamp']),
              style: GoogleFonts.ubuntu(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(reading['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    reading['status'].replaceAll('_', ' '),
                    style: GoogleFonts.ubuntu(
                      fontSize: 10,
                      color: _getStatusColor(reading['status']),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    reading['source'],
                    style: GoogleFonts.ubuntu(
                      fontSize: 10,
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (reading['fridge_on']) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'FRIDGE ON',
                      style: GoogleFonts.ubuntu(
                        fontSize: 10,
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: GoogleFonts.ubuntu(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        title: const Text("System Logs", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllLogs,
            tooltip: 'Refresh Logs',
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            // Tab Bar
            Container(
              color: Colors.grey[100],
              child: TabBar(
                labelColor: Colors.blue[700],
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: Colors.blue[700],
                tabs: const [
                  Tab(text: 'Surge Events'),
                  Tab(text: 'Sensor History'),
                ],
              ),
            ),

            Expanded(
              child: TabBarView(
                children: [
                  // SURGE EVENTS TAB
                  _isLoadingSurges
                      ? const Center(
                    child: CircularProgressIndicator(),
                  )
                      : _surgeLogs.isEmpty
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          "No surge events recorded",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                      : RefreshIndicator(
                    onRefresh: _loadSurgeLogs,
                    child: ListView.builder(
                      itemCount: _surgeLogs.length,
                      itemBuilder: (context, index) {
                        return _buildSurgeLogItem(_surgeLogs[index]);
                      },
                    ),
                  ),

                  // SENSOR HISTORY TAB
                  _isLoadingReadings
                      ? const Center(
                    child: CircularProgressIndicator(),
                  )
                      : _sensorHistory.isEmpty
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.show_chart, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          "No sensor data available",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                      : RefreshIndicator(
                    onRefresh: _loadSensorHistory,
                    child: ListView.builder(
                      itemCount: _sensorHistory.length,
                      itemBuilder: (context, index) {
                        return _buildSensorHistoryItem(_sensorHistory[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}