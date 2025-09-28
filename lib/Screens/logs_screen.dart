import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  _LogsScreenState createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final DatabaseReference _logsRef = FirebaseDatabase.instance.ref().child(
    "surges",
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // white background
      appBar: AppBar(
        backgroundColor: Colors.cyan,
        title: const Text("Surge Logs", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder(
        stream: _logsRef.onValue,
        builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
          if (!snapshot.hasData || snapshot.data?.snapshot.value == null) {
            return const Center(
              child: Text(
                "No logs available",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          Map<dynamic, dynamic> logs =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;

          // Sort logs by timestamp (most recent first)
          final sortedLogs =
              logs.entries.toList()..sort(
                (a, b) => b.value["timestamp"].compareTo(a.value["timestamp"]),
              );

          return ListView.builder(
            itemCount: sortedLogs.length,
            itemBuilder: (context, index) {
              var log = sortedLogs[index].value;
              String timestamp = log["timestamp"] ?? "Unknown";
              String status = log["status"] ?? "N/A";

              Color statusColor;
              if (status == "Danger") {
                statusColor = Colors.red;
              } else if (status == "Warning") {
                statusColor = Colors.orange;
              } else {
                statusColor = Colors.green;
              }

              return Card(
                color: Colors.white,
                elevation: 2,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(Icons.bolt, color: statusColor, size: 30),
                  title: Text(
                    "Status: $status",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    "Time: $timestamp",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
