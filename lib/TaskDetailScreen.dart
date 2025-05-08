import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({required this.taskId});

  @override
  _TaskDetailScreenState createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isEditing = false;
  TextEditingController _nameController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();

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
        title: Text('Chi tiết Task'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                // Lưu
                _updateTask(); // taskSnapshot sẽ không cần nữa
              } else {
                // Bật chế độ chỉnh sửa
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _firestore.collection('tasks').doc(widget.taskId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Đã xảy ra lỗi: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(child: Text('Không tìm thấy Task.'));
          }

          final taskData = snapshot.data!.data() as Map<String, dynamic>;

          final List<Map<String, dynamic>> logs =
              List<Map<String, dynamic>>.from(
                taskData['logs'] ?? [],
              ).reversed.toList();

          // Gán text controller nếu chưa gán
          if (!_isEditing) {
            if (_nameController.text != taskData['name']) {
              _nameController.text = taskData['name'] ?? '';
            }
            if (_descriptionController.text != taskData['description']) {
              _descriptionController.text = taskData['description'] ?? '';
            }
          }

          return Padding(
            padding: EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thông tin Task
                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _isEditing
                              ? TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Tên Task',
                                  border: OutlineInputBorder(),
                                ),
                              )
                              : Text(
                                'Tên Task: ${taskData['name']}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          SizedBox(height: 16),
                          _isEditing
                              ? TextFormField(
                                controller: _descriptionController,
                                decoration: InputDecoration(
                                  labelText: 'Mô tả',
                                  border: OutlineInputBorder(),
                                ),
                              )
                              : Text(
                                'Mô tả: ${taskData['description']}',
                                style: TextStyle(fontSize: 18),
                              ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  // Nhật ký Logs
                  Text(
                    'Nhật ký chỉnh sửa:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 10),
                  logs.isEmpty
                      ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text("Không có nhật ký nào."),
                      )
                      : Column(
                        children:
                            logs.map((log) {
                              return Card(
                                elevation: 3,
                                margin: EdgeInsets.symmetric(vertical: 5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.all(16),
                                  title: Text(
                                    log['action'],
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Bởi ${log['user']} lúc ${log['timestamp'] != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(log['timestamp'].toDate()) : 'N/A'}',
                                  ),
                                ),
                              );
                            }).toList(),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
