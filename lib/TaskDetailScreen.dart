import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  _TaskDetailScreenState createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isEditing = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateTask() async {
    Map<String, dynamic> logEntry = {
      'action': 'Cập nhật Task',
      'user': _auth.currentUser?.email ?? 'Unknown',
      'timestamp': Timestamp.now(),
    };

    await _firestore.collection('tasks').doc(widget.taskId).update({
      'name': _nameController.text,
      'description': _descriptionController.text,
      'logs': FieldValue.arrayUnion([logEntry]),
    });

    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết Task'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            tooltip: _isEditing ? 'Lưu' : 'Chỉnh sửa',
            onPressed: () {
              if (_isEditing) {
                _updateTask();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('tasks').doc(widget.taskId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Lỗi: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Không tìm thấy Task.'));
          }

          final taskData = snapshot.data!.data() as Map<String, dynamic>;

          final List<Map<String, dynamic>> logs =
              List<Map<String, dynamic>>.from(
                taskData['logs'] ?? [],
              ).reversed.toList();

          if (!_isEditing) {
            _nameController.text = taskData['name'] ?? '';
            _descriptionController.text = taskData['description'] ?? '';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Giao diện Task đẹp hơn
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _isEditing
                            ? TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Tên Task',
                                prefixIcon: Icon(Icons.title),
                                border: OutlineInputBorder(),
                              ),
                            )
                            : ListTile(
                              leading: const Icon(Icons.title),
                              title: const Text("Tên Task"),
                              subtitle: Text(
                                taskData['name'] ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                        const SizedBox(height: 16),
                        _isEditing
                            ? TextFormField(
                              controller: _descriptionController,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Mô tả',
                                prefixIcon: Icon(Icons.description),
                                border: OutlineInputBorder(),
                              ),
                            )
                            : ListTile(
                              leading: const Icon(Icons.description),
                              title: const Text("Mô tả"),
                              subtitle: Text(
                                taskData['description'] ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                /// Phần Logs (giữ nguyên)
                Text(
                  'Nhật ký chỉnh sửa:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                logs.isEmpty
                    ? const Text("Không có nhật ký nào.")
                    : ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(Icons.history),
                            title: Text(
                              log['action'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              'Bởi ${log['user']} lúc ${log['timestamp'] != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(log['timestamp'].toDate()) : 'N/A'}',
                            ),
                          ),
                        );
                      },
                    ),
              ],
            ),
          );
        },
      ),
    );
  }
}
