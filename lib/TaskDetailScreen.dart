import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isEditing = false;
  bool isEmployee = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _subtaskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final role = userDoc.data()?['role'] ?? '';
    setState(() {
      isEmployee = role == 'employee';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _updateTask() async {
    final logEntry = {
      'action': 'Cập nhật Task',
      'user': _auth.currentUser?.email ?? 'Unknown',
      'timestamp': Timestamp.now(),
    };

    await _firestore.collection('tasks').doc(widget.taskId).update({
      'name': _nameController.text,
      'description': _descriptionController.text,
      'logs': FieldValue.arrayUnion([logEntry]),
    });

    setState(() => _isEditing = false);
  }

  Future<void> _addSubtask(String title) async {
    final user = _auth.currentUser;
    if (title.isEmpty || user == null) return;

    await _firestore.collection('subtasks').add({
      'taskId': widget.taskId,
      'title': title,
      'status': 'To Do',
      'createdBy': user.uid,
      'createdByName': user.email,
      'createdAt': Timestamp.now(),
    });

    _subtaskController.clear();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'To Do':
        return Colors.grey.shade300;
      case 'Doing':
        return Colors.blue.shade100;
      case 'Done':
        return Colors.green.shade100;
      case 'Complete':
        return Colors.purple.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/user_screen'),
        ),
        title: const Text('Chi tiết công việc'),
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
          if (snapshot.hasError)
            return const Center(child: Text('Lỗi tải dữ liệu'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Không tìm thấy công việc'));
          }

          final taskData = snapshot.data!.data() as Map<String, dynamic>;
          final logs =
              List<Map<String, dynamic>>.from(
                taskData['logs'] ?? [],
              ).reversed.toList();

          if (!_isEditing) {
            _nameController.text = taskData['name'] ?? '';
            _descriptionController.text = taskData['description'] ?? '';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTaskInfoCard(taskData),
                const SizedBox(height: 24),
                _buildSubtaskSection(),
                const SizedBox(height: 24),
                _buildLogSection(logs),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskInfoCard(Map<String, dynamic> data) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _isEditing
                ? TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên Công Việc',
                    prefixIcon: Icon(Icons.title),
                    border: OutlineInputBorder(),
                  ),
                )
                : ListTile(
                  leading: const Icon(Icons.title),
                  title: const Text('Tên Công Việc'),
                  subtitle: Text(data['name'] ?? ''),
                ),
            const SizedBox(height: 16),
            _isEditing
                ? TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                )
                : ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Mô tả'),
                  subtitle: Text(data['description'] ?? ''),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtaskSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subtasks:',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream:
              _firestore
                  .collection('subtasks')
                  .where('taskId', isEqualTo: widget.taskId)
                  .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Text('Lỗi khi tải subtask');
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const CircularProgressIndicator();
            }

            final subtasks = snapshot.data!.docs;

            return Column(
              children: [
                ...subtasks.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final subtaskId = doc.id;

                  return Card(
                    color: _getStatusColor(data['status']),
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _getStatusColor(data['status']).withOpacity(0.7),
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        data['title'] ?? 'Chưa có tiêu đề',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Trạng thái: ${data['status'] ?? 'Chưa rõ'}',
                      ),
                      trailing:
                          !_isEditing && isEmployee
                              ? DropdownButton<String>(
                                value: data['status'],
                                items:
                                    ['To Do', 'Doing', 'Done', 'Complete'].map((
                                      status,
                                    ) {
                                      return DropdownMenuItem(
                                        value: status,
                                        child: Text(status),
                                      );
                                    }).toList(),
                                onChanged: (newStatus) {
                                  if (newStatus != null) {
                                    _firestore
                                        .collection('subtasks')
                                        .doc(subtaskId)
                                        .update({'status': newStatus});
                                  }
                                },
                              )
                              : null,
                    ),
                  );
                }),

                if (!_isEditing && isEmployee)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _subtaskController,
                            decoration: const InputDecoration(
                              hintText: 'Nhập tên subtask...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _addSubtask(_subtaskController.text),
                          icon: const Icon(Icons.add),
                          label: const Text('Thêm'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildLogSection(List<Map<String, dynamic>> logs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nhật ký chỉnh sửa:',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 300, // huynh có thể chỉnh chiều cao này theo ý
          child:
              logs.isEmpty
                  ? const Text("Không có nhật ký nào.")
                  : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(
                            log['action'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Bởi ${log['user']} lúc ${log['timestamp'] != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(log['timestamp'].toDate()) : 'N/A'}',
                          ),
                        ),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}
