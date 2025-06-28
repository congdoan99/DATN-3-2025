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
  String _selectedUserName = 'Tất cả';

  late Future<Map<String, dynamic>> _statisticsFuture;
  Map<String, dynamic>? _cachedStats;

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
          _statisticsFuture = _getStatistics();
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

  Future<List<Map<String, dynamic>>> _getEmployeeTaskCount() async {
    final userSnapshot =
        await _firestore
            .collection('users')
            .where('role', whereIn: ['employee', 'staff'])
            .get();

    final taskSnapshot = await _firestore.collection('tasks').get();
    Map<String, int> taskCounts = {};
    for (var doc in taskSnapshot.docs) {
      final assigneeId = doc['assigneeId'];
      if (assigneeId != null && assigneeId != '') {
        taskCounts[assigneeId] = (taskCounts[assigneeId] ?? 0) + 1;
      }
    }

    List<Map<String, dynamic>> result = [];
    for (var userDoc in userSnapshot.docs) {
      final userData = userDoc.data();
      final uid = userDoc.id;
      result.add({
        'id': uid,
        'name':
            (userData['fullName'] != null &&
                    userData['fullName'].toString().trim().isNotEmpty)
                ? userData['fullName']
                : userData['email'] ?? 'Không rõ',
        'email': userData['email'] ?? '',
        'taskCount': taskCounts[uid] ?? 0,
      });
    }

    return result;
  }

  Future<Map<String, dynamic>> _getStatistics() async {
    final tasksStats = await _getTaskStatistics();
    final completedProjects = await _getCompletedProjectsCount();
    final employeeStats =
        _userData?['role'] == 'manager' ? await _getEmployeeTaskCount() : [];

    return {
      'tasks': tasksStats,
      'completedProjects': completedProjects,
      'employeeStats': employeeStats,
    };
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
      body:
          _userData == null
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<Map<String, dynamic>>(
                future: _statisticsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: Text("Không có dữ liệu thống kê."),
                    );
                  }

                  _cachedStats = snapshot.data!;
                  final Map<String, int> data = Map<String, int>.from(
                    _cachedStats!['tasks'] ?? {},
                  );
                  final int completedProjects =
                      _cachedStats!['completedProjects'] ?? 0;
                  final totalTasks = data.values.fold(0, (a, b) => a + b);
                  final employeeStats = List<Map<String, dynamic>>.from(
                    _cachedStats!['employeeStats'] ?? [],
                  );

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(totalTasks, completedProjects),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView(
                            children: [
                              ...data.entries.map((entry) {
                                final percent =
                                    totalTasks > 0
                                        ? entry.value / totalTasks
                                        : 0;
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
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
                                                value:
                                                    (entry.value / totalTasks)
                                                        .toDouble(),
                                                backgroundColor:
                                                    Colors.grey[200],
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(_getTaskColor(entry.key)),
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
                              }),
                              if (_userData?['role'] == 'manager' &&
                                  employeeStats.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Tổng số công việc theo nhân viên:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    DropdownButton<String>(
                                      value: _selectedUserName,
                                      borderRadius: BorderRadius.circular(12),
                                      items: [
                                        const DropdownMenuItem(
                                          value: 'Tất cả',
                                          child: Text('Tất cả'),
                                        ),
                                        ...employeeStats.map(
                                          (user) => DropdownMenuItem(
                                            value: user['name'],
                                            child: Text(user['name']),
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedUserName = value!;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ..._buildEmployeeTaskList(employeeStats),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
    );
  }

  List<Widget> _buildEmployeeTaskList(List<Map<String, dynamic>> employees) {
    final filtered =
        employees
            .where(
              (user) =>
                  _selectedUserName == 'Tất cả' ||
                  user['name'] == _selectedUserName,
            )
            .toList();

    return [
      ...filtered.map(
        (user) => ListTile(
          leading: Icon(
            user['taskCount'] == 0 ? Icons.person_outline : Icons.person,
            color: user['taskCount'] == 0 ? Colors.grey : Colors.black,
          ),
          title: Text(user['name']),
          subtitle: Text(user['email']),
          trailing: Text(
            '${user['taskCount']} công việc',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      if (_selectedUserName != 'Tất cả' &&
          filtered.isNotEmpty &&
          filtered[0]['taskCount'] == 0)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Center(
            child: Text(
              '⚠️ Nhân viên này hiện chưa có công việc nào.',
              style: TextStyle(
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
    ];
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
