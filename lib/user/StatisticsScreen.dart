import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  Future<int> _getCompletedProjectsCount() async {
    if (_user == null || _userData == null) return 0;

    QuerySnapshot snapshot;

    if (_userData?['role'] == 'manager') {
      snapshot =
          await _firestore
              .collection('projects')
              .where('status', isEqualTo: 'Complete')
              .get();
    } else {
      snapshot =
          await _firestore
              .collection('projects')
              .where('status', isEqualTo: 'Complete')
              .where('memberIds', arrayContains: _user!.uid)
              .get();
    }

    return snapshot.size;
  }

  Future<Map<String, dynamic>> _getStatistics() async {
    final tasksStats = await _getTaskStatistics();
    final completedProjects = await _getCompletedProjectsCount();

    return {'tasks': tasksStats, 'completedProjects': completedProjects};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [SizedBox(width: 8), Text('Thống Kê Công Việc')],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/user_screen'),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getStatistics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("Không có dữ liệu thống kê."));
          }

          final Map<String, int> data = Map<String, int>.from(
            snapshot.data!['tasks'] ?? {},
          );
          final int completedProjects =
              snapshot.data!['completedProjects'] ?? 0;
          final totalTasks = data.values.fold(0, (a, b) => a + b);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(totalTasks, completedProjects),
                const SizedBox(height: 16),
                if (totalTasks == 0)
                  const Expanded(
                    child: Center(
                      child: Text("Không có dữ liệu thống kê công việc."),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children:
                          data.entries.map((entry) {
                            final double percent =
                                totalTasks > 0 ? entry.value / totalTasks : 0;
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 3,
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: _getTaskColor(
                                        entry.key,
                                      ).withOpacity(0.15),
                                      child: Icon(
                                        _getTaskIcon(entry.key),
                                        color: _getTaskColor(entry.key),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entry.key,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          LinearProgressIndicator(
                                            value: percent,
                                            backgroundColor: Colors.grey[200],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  _getTaskColor(entry.key),
                                                ),
                                            minHeight: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      children: [
                                        Text(
                                          '${entry.value}',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          '${(percent * 100).toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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

  Widget _buildSummaryCard(int totalTasks, int completedProjects) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Số dự án đã hoàn thành: $completedProjects',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tổng số công việc: $totalTasks',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTaskColor(String status) {
    switch (status) {
      case 'To Do':
        return Colors.grey;
      case 'Doing':
        return Colors.orange;
      case 'Done':
        return Colors.green;
      case 'Complete':
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getTaskIcon(String status) {
    switch (status) {
      case 'To Do':
        return Icons.pending_actions;
      case 'Doing':
        return Icons.autorenew;
      case 'Done':
        return Icons.task_alt;
      case 'Complete':
        return Icons.verified;
      default:
        return Icons.task;
    }
  }
}
