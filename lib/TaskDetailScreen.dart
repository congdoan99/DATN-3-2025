import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  TaskDetailScreen({required this.taskId});

  @override
  _TaskDetailScreenState createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  Map<String, dynamic>? _taskData;
  List<Map<String, dynamic>> _subtasks = [];
  List<Map<String, dynamic>> _logs = [];
  bool _isEditing = false;

  TextEditingController _nameController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _fetchTaskDetails();
  }

  Future<void> _fetchTaskDetails() async {
    DocumentSnapshot taskDoc =
        await _firestore.collection('tasks').doc(widget.taskId).get();
    if (taskDoc.exists) {
      setState(() {
        _taskData = taskDoc.data() as Map<String, dynamic>;
        _nameController.text = _taskData?['name'] ?? '';
        _descriptionController.text = _taskData?['description'] ?? '';
        _subtasks = List<Map<String, dynamic>>.from(
          _taskData?['subtasks'] ?? [],
        );
        _logs = List<Map<String, dynamic>>.from(_taskData?['logs'] ?? []);
      });
    }
  }

  Future<void> _updateTask() async {
    if (_taskData != null) {
      _taskData?['name'] = _nameController.text;
      _taskData?['description'] = _descriptionController.text;

      await _firestore
          .collection('tasks')
          .doc(widget.taskId)
          .update(_taskData!);
      _addLog("Task updated");
      setState(() {
        _isEditing = false; // Sau khi lưu, chuyển lại về chế độ xem.
      });
    }
  }

  Future<void> _addLog(String action) async {
    Map<String, dynamic> logEntry = {
      'action': action,
      'user': _user?.email ?? 'Unknown',
      'timestamp': Timestamp.now(),
    };

    await _firestore.collection('tasks').doc(widget.taskId).update({
      'logs': FieldValue.arrayUnion([logEntry]),
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dùng MediaQuery để lấy kích thước màn hình của thiết bị
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text('Task Detail'),
        actions: [
          // Hiển thị nút chỉnh sửa/ lưu trên AppBar
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              setState(() {
                if (_isEditing) {
                  // Khi nhấn lưu, thực hiện cập nhật task
                  _updateTask();
                } else {
                  // Chuyển sang chế độ chỉnh sửa
                  _isEditing = true;
                }
              });
            },
          ),
        ],
      ),
      body:
          _taskData == null
              ? Center(child: CircularProgressIndicator())
              : Padding(
                padding: EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task Information (only viewable)
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
                                    'Tên Task: ${_taskData?['name']}',
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
                                    'Mô tả: ${_taskData?['description']}',
                                    style: TextStyle(fontSize: 18),
                                  ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      // Logs Section
                      Text(
                        'Nhật ký chỉnh sửa:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 10),
                      // Display Logs in Cards
                      _logs.isEmpty
                          ? Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text("Không có nhật ký nào."),
                          )
                          : Column(
                            children:
                                _logs.map((log) {
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
                                        'By ${log['user']} at ${log['timestamp'] != null ? DateFormat('dd/MM/yyyy HH:mm:ss').format(log['timestamp'].toDate()) : 'N/A'}',
                                      ),
                                    ),
                                  );
                                }).toList(),
                          ),
                    ],
                  ),
                ),
              ),
    );
  }
}
