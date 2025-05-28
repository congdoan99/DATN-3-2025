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

  // Hàm lấy thống kê task (giữ nguyên)
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

  // Hàm mới: lấy số project hoàn thành
  Future<int> _getCompletedProjectsCount() async {
    if (_user == null || _userData == null) return 0;

    QuerySnapshot snapshot;

    if (_userData?['role'] == 'manager') {
      // Manager xem tất cả project đã hoàn thành
      snapshot =
          await _firestore
              .collection('projects')
              .where('status', isEqualTo: 'Complete')
              .get();
    } else {
      // User thường chỉ xem project liên quan (ví dụ có field memberIds hoặc assigneeId)
      // Giả sử project có danh sách memberIds chứa userId
      snapshot =
          await _firestore
              .collection('projects')
              .where('status', isEqualTo: 'Complete')
              .where('memberIds', arrayContains: _user!.uid)
              .get();
    }

    return snapshot.size;
  }

  // Hàm kết hợp lấy cả thống kê task + project
  Future<Map<String, dynamic>> _getStatistics() async {
    final tasksStats = await _getTaskStatistics();
    final completedProjects = await _getCompletedProjectsCount();

    return {'tasks': tasksStats, 'completedProjects': completedProjects};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Thống kê công việc'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/user_screen'),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getStatistics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return Center(child: Text("Không có dữ liệu thống kê."));
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
                Text(
                  'Tổng số công việc: $totalTasks',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Số project hoàn thành: $completedProjects',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 16),

                if (totalTasks == 0)
                  Center(child: Text("Không có dữ liệu thống kê công việc.")),

                // Danh sách trạng thái công việc
                ...data.entries.map((entry) {
                  final double percent =
                      totalTasks > 0 ? entry.value / totalTasks : 0;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Icon(
                            _getTaskIcon(entry.key),
                            color: _getTaskColor(entry.key),
                            size: 28,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percent,
                                    backgroundColor: _getTaskColor(
                                      entry.key,
                                    ).withOpacity(0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getTaskColor(entry.key),
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            '${entry.value}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
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

  IconData _getTaskIcon(String status) {
    switch (status) {
      case 'To Do':
        return Icons.pending_actions;
      case 'Doing':
        return Icons.loop;
      case 'Done':
        return Icons.check_circle_outline;
      case 'Complete':
        return Icons.verified;
      default:
        return Icons.task;
    }
  }
}
