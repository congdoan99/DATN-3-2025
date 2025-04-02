import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProjectDetailScreen extends StatelessWidget {
  final String projectId;
  final String projectName;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  Future<String> _getUserRole() async {
    try {
      String userId = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      return userDoc['role'];
    } catch (e) {
      print("Lỗi khi lấy quyền người dùng: $e");
      return "unknown";
    }
  }

  Future<void> _addLog(String taskId, String action) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    Map<String, dynamic> logEntry = {
      'action': action,
      'user': user.email ?? 'Unknown',
      'timestamp': Timestamp.now(),
    };

    await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
      'logs': FieldValue.arrayUnion([logEntry]),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý Công Việc - $projectName'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () async {
            String role = await _getUserRole();
            if (role == 'admin') {
              context.go('/create_project');
            } else {
              context.go('/user_screen');
            }
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('projects')
                .doc(projectId)
                .collection('processes')
                .orderBy('order')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Không có process nào.'));
          }

          List<Map<String, dynamic>> defaultProcesses = [
            {'name': 'To Do', 'order': 0},
            {'name': 'Doing', 'order': 1},
            {'name': 'Done', 'order': 2},
            {'name': 'Complete', 'order': 3},
          ];

          List<Map<String, dynamic>> processes =
              snapshot.data!.docs.map((doc) {
                return {
                  'id': doc.id,
                  'name': doc['name'],
                  'order': doc['order'],
                };
              }).toList();

          for (var defaultProcess in defaultProcesses) {
            if (!processes.any((p) => p['name'] == defaultProcess['name'])) {
              processes.add({
                'id': null,
                'name': defaultProcess['name'],
                'order': defaultProcess['order'],
              });
            }
          }

          if (snapshot.hasData) {
            for (var process in processes) {
              if (process['id'] == null) {
                FirebaseFirestore.instance
                    .collection('projects')
                    .doc(projectId)
                    .collection('processes')
                    .add({'name': process['name'], 'order': process['order']});
              }
            }
          }

          processes.sort((a, b) => a['order'].compareTo(b['order']));

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  processes.map((process) {
                    return ProcessColumn(
                      projectId: projectId,
                      processId: process['id'],
                      processName: process['name'],
                      addLog: (taskId, action) => _addLog(taskId, action),
                    );
                  }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class ProcessColumn extends StatefulWidget {
  final String projectId;
  final String processId;
  final String processName;
  final Function(String taskId, String action) addLog;

  const ProcessColumn({
    super.key,
    required this.projectId,
    required this.processId,
    required this.processName,
    required this.addLog,
  });

  @override
  State<ProcessColumn> createState() => _ProcessColumnState();
}

class _ProcessColumnState extends State<ProcessColumn> {
  Future<void> _moveTask(
    String taskId,
    String fromProcessId,
    String toProcessName,
  ) async {
    try {
      QuerySnapshot processQuery =
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(widget.projectId)
              .collection('processes')
              .where('name', isEqualTo: toProcessName)
              .limit(1)
              .get();

      if (processQuery.docs.isEmpty) return;

      String newProcessId = processQuery.docs.first.id;

      await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
        'processId': newProcessId,
        'status': toProcessName,
      });

      // Ghi lại log thay đổi
      await widget.addLog(taskId, "Moved to $toProcessName");
    } catch (e) {
      print("Lỗi khi di chuyển task: $e");
    }
  }

  void _addTask(BuildContext context) async {
    TextEditingController taskController = TextEditingController();
    String? selectedUser;

    List<Map<String, String>> users = [];

    // Lấy danh sách nhân viên từ Firestore
    QuerySnapshot userSnapshot =
        await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'employee')
            .get();

    users =
        userSnapshot.docs.map((doc) {
          return {'id': doc.id, 'fullName': doc['fullName'].toString()};
        }).toList();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Thêm Task vào ${widget.processName}"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: taskController,
                    decoration: InputDecoration(hintText: "Nhập tên task"),
                  ),
                  SizedBox(height: 10),
                  users.isEmpty
                      ? Text("Không có người dùng nào")
                      : DropdownButton<String>(
                        value: selectedUser,
                        hint: Text("Chọn người thực hiện"),
                        isExpanded: true,
                        items:
                            users.map((user) {
                              return DropdownMenuItem<String>(
                                value: user['id'],
                                child: Text(user['fullName'] ?? "Không tên"),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedUser = value;
                          });
                        },
                      ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Hủy"),
                ),
                TextButton(
                  onPressed: () async {
                    if (taskController.text.trim().isNotEmpty &&
                        selectedUser != null) {
                      try {
                        String taskId =
                            FirebaseFirestore.instance
                                .collection('tasks')
                                .doc()
                                .id;
                        await FirebaseFirestore.instance
                            .collection('tasks')
                            .doc(taskId)
                            .set({
                              'id': taskId,
                              'name': taskController.text.trim(),
                              'projectId': widget.projectId,
                              'processId': widget.processId,
                              'assigneeId': selectedUser,
                              'createdAt': Timestamp.now(),
                            });
                        Navigator.pop(context);
                      } catch (e) {
                        print("Lỗi khi thêm task: $e");
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Vui lòng nhập đầy đủ thông tin"),
                        ),
                      );
                    }
                  },
                  child: Text("Thêm"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getColumnColor(String processName) {
    switch (processName) {
      case 'To Do':
        return Colors.orange[200]!;
      case 'Doing':
        return Colors.blue[200]!;
      case 'Done':
        return Colors.green[200]!;
      case 'Complete':
        return Colors.purple[200]!;
      default:
        return Colors.grey[200]!;
    }
  }

  Future<int> _getTaskCount(String processId) async {
    try {
      QuerySnapshot tasksSnapshot =
          await FirebaseFirestore.instance
              .collection('tasks')
              .where('processId', isEqualTo: processId)
              .get();
      return tasksSnapshot.docs.length;
    } catch (e) {
      print("Lỗi khi lấy số lượng task: $e");
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<Map<String, String>>(
      onAcceptWithDetails: (details) {
        var data = details.data;
        String taskId = data['taskId']!;
        String fromProcessId = data['fromProcessId']!;
        _moveTask(taskId, fromProcessId, widget.processName);
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          width: 250,
          margin: EdgeInsets.all(10),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _getColumnColor(widget.processName),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.processName,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              FutureBuilder<int>(
                future: _getTaskCount(widget.processId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Text("Đang tải...");
                  }
                  if (snapshot.hasError) {
                    return Text("Lỗi khi tải số lượng task");
                  }
                  return Text("Số lượng task: ${snapshot.data}");
                },
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      FirebaseFirestore.instance
                          .collection('tasks')
                          .where('projectId', isEqualTo: widget.projectId)
                          .where('processId', isEqualTo: widget.processId)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData)
                      return Center(child: CircularProgressIndicator());
                    var tasks = snapshot.data!.docs;
                    return ListView(
                      children:
                          tasks.map((task) {
                            return Draggable<Map<String, String>>(
                              data: {
                                'taskId': task.id,
                                'fromProcessId': widget.processId,
                              },
                              feedback: Material(
                                child: Card(
                                  color: Colors.blueAccent,
                                  child: Padding(
                                    padding: EdgeInsets.all(8.0),
                                    child: Text(
                                      task['name'],
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.5,
                                child: Card(
                                  child: ListTile(title: Text(task['name'])),
                                ),
                              ),
                              child: Card(
                                margin: EdgeInsets.symmetric(vertical: 5),
                                child: ListTile(title: Text(task['name'])),
                              ),
                            );
                          }).toList(),
                    );
                  },
                ),
              ),
              if (widget.processName == "To Do")
                ElevatedButton(
                  onPressed: () => _addTask(context),
                  child: Text("+ Thêm Task"),
                ),
            ],
          ),
        );
      },
    );
  }
}
