import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool changeOverSwitch = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Surge Monitor"),
      ),
      body: const HomeDashboard(),
    );
  }
}

class HomeDashboard extends StatefulWidget {
  const HomeDashboard({super.key});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  bool changeOverSwitch = false;
  bool fridgeSwitch = false;

  // Firebase references
  final DatabaseReference _currentStatusRef = FirebaseDatabase.instance.ref('current_status');
  final DatabaseReference _controlRef = FirebaseDatabase.instance.ref('device_control');
  final DatabaseReference _manualOverrideRef = FirebaseDatabase.instance.ref('device_control/changeover/manual_override');

  // Real-time sensor data from ESP32
  double voltage = 0.0;
  double current = 0.0;
  double power = 0.0;
  String systemStatus = "Normal";
  String powerSource = "Grid";
  bool manualOverride = false;

  // AI Prediction and Chart Data
  double surgePredictionPercent = 0.0;
  List<FlSpot> powerData = [];
  int timeCounter = 0;
  Timer? graphTimer;

  @override
  void initState() {
    super.initState();
    startFirebaseListeners();
    startGraphUpdates();
    _testFirebaseConnection();
  }

  void _testFirebaseConnection() async {
    try {
      DatabaseEvent testEvent = await _currentStatusRef.once();
      print('✅ Firebase Connection Test: SUCCESS');
      print('📁 Data at /current_status: ${testEvent.snapshot.value}');
    } catch (e) {
      print('❌ Firebase Connection Test: FAILED - $e');
    }
  }

  void startFirebaseListeners() {
    print('🎯 Listening to /current_status path for real-time data...');

    // Listen to current_status for real-time updates
    _currentStatusRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value;
      print('🔥 REAL-TIME Data from /current_status: $data');

      if (data != null && data is Map) {
        _processCurrentStatus(data as Map<dynamic, dynamic>);
      }
    });

    // Listen to manual override changes
    _manualOverrideRef.onValue.listen((DatabaseEvent event) {
      print('🔄 Manual override updated: ${event.snapshot.value}');
    });
  }

  void _processCurrentStatus(Map<dynamic, dynamic> statusData) {
    print('🔍 Processing current_status: $statusData');

    setState(() {
      // Extract values from current_status
      double newVoltage = _parseDouble(statusData['voltage']) ?? 0.0;
      double newCurrent = _parseDouble(statusData['current']) ?? 0.0;
      double newPower = _parseDouble(statusData['power']) ?? 0.0;
      String newStatus = statusData['status']?.toString() ?? "Normal";
      String newSource = statusData['power_source']?.toString() ?? "Grid";
      bool newManualOverride = (statusData['manual_override'] as bool?) ?? false;

      print('📊 Extracted - V: $newVoltage, I: $newCurrent, P: $newPower, Source: $newSource, Manual Override: $newManualOverride');

      // Update UI state
      voltage = newVoltage;
      current = newCurrent;
      power = newPower;
      systemStatus = newStatus;
      powerSource = newSource;
      manualOverride = newManualOverride;

      // Update toggle based on power source
      changeOverSwitch = powerSource.toLowerCase() == "solar";

      surgePredictionPercent = _calculateSurgePrediction(voltage);

      print('🎯 UI UPDATED - V: ${voltage}V, I: ${current}A, P: ${power}W, Source: $powerSource');
    });
  }

  // Helper method to safely parse doubles
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  // Helper method to calculate dynamic Y-axis maximum
  double _calculateMaxY(List<FlSpot> data) {
    if (data.isEmpty) return 100.0; // Default to 100W when no data

    double maxY = data.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);
    double paddedMax = maxY * 1.2;

    // Ensure we have a reasonable minimum range for visualization
    if (paddedMax < 100) return 100.0;
    return paddedMax;
  }

  void startGraphUpdates() {
    print('📈 Starting graph with REAL Firebase data only...');

    // Clear any existing data to start fresh
    powerData.clear();
    timeCounter = 0;

    // Update graph when new Firebase data arrives
    graphTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          timeCounter++;

          // ✅ FIXED: Use ONLY the ACTUAL power value from Firebase - NO SIMULATION
          double graphPower = power;

          // Add new data point with actual power value (even if it's 0)
          powerData.add(FlSpot(timeCounter.toDouble(), graphPower));

          // Keep only last 50 points
          if (powerData.length > 50) {
            powerData.removeAt(0);
          }

          print('📈 Graph - Points: ${powerData.length}/50, Power: ${graphPower.toStringAsFixed(1)}W, Time: $timeCounter');
        });
      }
    });
  }

  // Simulate AI surge prediction
  double _calculateSurgePrediction(double voltage) {
    if (voltage > 250) return 0.9;
    if (voltage > 240) return 0.7;
    if (voltage > 230) return 0.4;
    return 0.1;
  }

  // Send changeover command to ESP32
  Future<void> sendChangeoverCommand(bool switchToSolar) async {
    bool originalState = changeOverSwitch;

    try {
      String newSource = switchToSolar ? 'solar' : 'grid';

      // Immediately update UI for better responsiveness
      setState(() {
        changeOverSwitch = switchToSolar;
      });

      // Send command to ESP32
      await _manualOverrideRef.set(newSource);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            switchToSolar ? '🔆 Switching to Solar...' : '🔌 Switching to Grid...',
          ),
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      // Revert toggle on error
      setState(() {
        changeOverSwitch = originalState;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Command failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Send fridge command to ESP32
  Future<void> sendFridgeCommand(bool turnOn) async {
    bool originalState = fridgeSwitch;

    try {
      // Immediately update UI
      setState(() {
        fridgeSwitch = turnOn;
      });

      await _controlRef.child('fridge').set({
        'status': turnOn ? 'on' : 'off',
        'timestamp': ServerValue.timestamp,
        'command_by': 'flutter_app',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            turnOn ? '❄️ Fridge turning ON...' : '⏸️ Fridge turning OFF...',
          ),
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      // Revert toggle on error
      setState(() {
        fridgeSwitch = originalState;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Fridge control failed: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Only 2 boxes (Voltage & Current)
  Widget _buildGridItem(int index) {
    final List<Map<String, dynamic>> items = [
      {
        'icon': Icons.electric_bolt,
        'color': Colors.orange,
        'title': 'Voltage',
        'status': '${voltage.toStringAsFixed(1)}V',
        'value': voltage,
      },
      {
        'icon': Icons.battery_charging_full,
        'color': Colors.green,
        'title': 'Current',
        'status': '${current.toStringAsFixed(2)}A',
        'value': current,
      },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            items[index]['icon'],
            size: 32,
            color: items[index]['color'],
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                items[index]['title'],
                style: GoogleFonts.ubuntu(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                items[index]['status'],
                style: GoogleFonts.ubuntu(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'danger':
      case 'surge_detected':
      case 'auto_surge':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  // Helper method for risk color
  Color _getRiskColor(double percent) {
    if (percent < 0.3) return Colors.green;
    if (percent < 0.7) return Colors.orange;
    return Colors.red;
  }

  String _getRiskText(double percent) {
    if (percent < 0.2) return 'Very Low Risk';
    if (percent < 0.4) return 'Low Risk';
    if (percent < 0.6) return 'Medium Risk';
    if (percent < 0.8) return 'High Risk';
    return 'Critical Risk';
  }

  @override
  void dispose() {
    graphTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          print('🔄 Manual refresh triggered');
        });
        await Future.delayed(Duration(milliseconds: 1000));
      },
      child: _buildHomeContent(),
    );
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // 🔹 Switch between Solar and Grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.sunny, color: Colors.yellow[700], size: 22),
                    const SizedBox(width: 4),
                    Icon(Icons.lightbulb_outline_rounded,
                        color: Colors.yellow[700], size: 22),
                    const SizedBox(width: 6),
                    Text(
                      changeOverSwitch ? 'Solar' : 'Grid',
                      style: GoogleFonts.ubuntu(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                Switch.adaptive(
                  value: changeOverSwitch,
                  onChanged: (value) {
                    sendChangeoverCommand(value);
                  },
                )
              ],
            ),

            const SizedBox(height: 12),

            // 🔹 System Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'System Status',
                  style: GoogleFonts.ubuntu(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      systemStatus.replaceAll('_', ' '),
                      style: GoogleFonts.ubuntu(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(systemStatus),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getStatusColor(systemStatus),
                        shape: BoxShape.circle,
                      ),
                    )
                  ],
                )
              ],
            ),

            const SizedBox(height: 12),

            // 🔹 Sensor Readings Grid - 2 boxes only
            SizedBox(
              height: 100,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 2,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.0,
                ),
                itemBuilder: (context, index) => _buildGridItem(index),
              ),
            ),

            const SizedBox(height: 12),

            // 🔹 Power Display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.power, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Power: ${power.toStringAsFixed(1)}W',
                    style: GoogleFonts.ubuntu(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[800],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 🔹 Fridge Control
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                          fridgeSwitch ? Icons.kitchen : Icons.kitchen_outlined,
                          color: fridgeSwitch ? Colors.blue[700] : Colors.grey[600],
                          size: 22
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Fridge Control',
                            style: GoogleFonts.ubuntu(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            fridgeSwitch ? 'ON' : 'OFF',
                            style: GoogleFonts.ubuntu(
                              fontSize: 12,
                              color: fridgeSwitch ? Colors.green : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: fridgeSwitch,
                    onChanged: (value) {
                      sendFridgeCommand(value);
                    },
                  )
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 🔹 Status Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: systemStatus.toLowerCase().contains("surge") ? Colors.orange[100] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    systemStatus.toLowerCase().contains("surge") ? Icons.warning_amber_rounded : Icons.check_circle,
                    size: 40,
                    color: systemStatus.toLowerCase().contains("surge") ? Colors.orange : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          systemStatus.toLowerCase().contains("surge") ? 'Surge Detected!' : 'System Normal',
                          style: GoogleFonts.ubuntu(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          systemStatus.toLowerCase().contains("surge") ? 'Switched to safety mode' : 'All systems operational',
                          style: GoogleFonts.ubuntu(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 🔹 AI Prediction Section
            Container(
              height: 120,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Prediction',
                          style: GoogleFonts.ubuntu(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getRiskText(surgePredictionPercent),
                          style: GoogleFonts.ubuntu(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getRiskColor(surgePredictionPercent),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(surgePredictionPercent * 100).toStringAsFixed(0)}% Risk',
                          style: GoogleFonts.ubuntu(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: surgePredictionPercent,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getRiskColor(surgePredictionPercent),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 🔹 Power Graph - REAL DATA ONLY
            Container(
              height: 250,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Power Consumption',
                        style: GoogleFonts.ubuntu(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Points: ${powerData.length}/50',
                        style: GoogleFonts.ubuntu(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Current: ${power.toStringAsFixed(1)} W',
                    style: GoogleFonts.ubuntu(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: powerData.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.show_chart, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text(
                            'Waiting for data...',
                            style: GoogleFonts.ubuntu(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                        : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: false),
                        titlesData: FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        minX: powerData.first.x,
                        maxX: powerData.last.x,
                        minY: 0,
                        maxY: _calculateMaxY(powerData),
                        lineBarsData: [
                          LineChartBarData(
                            spots: powerData,
                            isCurved: true,
                            color: power > 0 ? Colors.blue : Colors.grey, // Grey when no power
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: (power > 0 ? Colors.blue : Colors.grey).withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}