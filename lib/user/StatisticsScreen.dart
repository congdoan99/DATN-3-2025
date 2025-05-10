import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class StatisticsScreen extends StatefulWidget {
  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _fetchUserData();
  }

  void _fetchUserData() async {
    if (_user != null) {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(_user!.uid).get();
      if (userDoc.exists) {
        setState(() {
          _userData = userDoc.data() as Map<String, dynamic>;
        });
      }
    }
  }

  Future<Map<String, int>> _getTaskStatistics() async {
    if (_user == null || _userData == null) return {};

    QuerySnapshot snapshot;

    if (_userData?['role'] == 'manager') {
      snapshot = await _firestore.collection('tasks').get();
    } else {
      snapshot =
          await _firestore
              .collection('tasks')
              .where('assigneeId', isEqualTo: _user!.uid)
              .get();
    }

    Map<String, int> stats = {'To Do': 0, 'Doing': 0, 'Done': 0, 'Complete': 0};

    for (var doc in snapshot.docs) {
      String status = doc['status'] ?? 'To Do';
      if (stats.containsKey(status)) {
        stats[status] = stats[status]! + 1;
      }
    }

    return stats;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Thống kê công việc')),
      body: FutureBuilder<Map<String, int>>(
        future: _getTaskStatistics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? {};
          final total = data.values.fold(0, (a, b) => a + b);

          if (data.isEmpty || total == 0) {
            return Center(child: Text("Không có dữ liệu thống kê."));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pie chart bên trái
                Expanded(
                  flex: 1,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: PieChart(
                      PieChartData(
                        sections:
                            data.entries.map((entry) {
                              final double percent = entry.value / total * 100;
                              return PieChartSectionData(
                                value: entry.value.toDouble(),
                                title: '${percent.toStringAsFixed(1)}%',
                                color: _getTaskColor(entry.key),
                                radius: 60,
                                titleStyle: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                ),

                SizedBox(width: 24),

                // Danh sách trạng thái bên phải
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        data.entries.map((entry) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: _getTaskColor(entry.key),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(child: Text(entry.key)),
                                Text('${entry.value}'),
                              ],
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getTaskColor(String status) {
    switch (status) {
      case 'To Do':
        return Colors.grey;
      case 'Doing':
        return Colors.blue;
      case 'Done':
        return Colors.green;
      case 'Complete':
        return Colors.purple;
      default:
        return Colors.black;
    }
  }
}
