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
        title: Text('Quản Lý Dự Án - $projectName'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () async {
            // Lấy thông tin từ màn trước
            final extra = GoRouterState.of(context).extra;
            String? fromScreen;
            if (extra is Map<String, dynamic>) {
              fromScreen = extra['from'] as String?;
            }

            if (fromScreen == 'search') {
              context.go('/search-project');
            } else {
              String role = await _getUserRole();
              if (role == 'admin') {
                context.go('/project_list');
              } else {
                context.go('/user_screen');
              }
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

          List<Map<String, dynamic>> processes =
              snapshot.data!.docs.map((doc) {
                return {
                  'id': doc.id,
                  'name': doc['name'],
                  'order': doc['order'],
                };
              }).toList();

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
  Future<String> _getCurrentUserRole() async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc['role'];
  }

  Future<void> _moveTask(
    String taskId,
    String fromProcessId,
    String toProcessName,
  ) async {
    try {
      // Kiểm tra điều kiện trước khi di chuyển task
      final isValid = await _canMoveTaskToStatus(taskId, toProcessName);
      if (!isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể chuyển trạng thái. Các công việc con chưa hoàn thành.',
            ),
          ),
        );
        return;
      }

      // Lấy ID process mới
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
        'completedAt':
            toProcessName == 'Complete' ? FieldValue.serverTimestamp() : null,
      });

      await widget.addLog(taskId, "Moved to $toProcessName");
      if (toProcessName == 'Complete') {
        await _checkAndUpdateProjectStatus(widget.projectId);
      }

      if (mounted) setState(() {});
    } catch (e) {
      print("Lỗi khi di chuyển task: $e");
    }
  }

  Future<void> _checkAndUpdateProjectStatus(String projectId) async {
    final taskSnapshot =
        await FirebaseFirestore.instance
            .collection('tasks')
            .where('projectId', isEqualTo: projectId)
            .get();

    final allCompleted = taskSnapshot.docs.every(
      (doc) => doc['status'] == 'Complete',
    );

    if (allCompleted && taskSnapshot.docs.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .update({'status': 'Complete'});
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
                        // Lấy tên người được chọn
                        final assigneeDoc =
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(selectedUser)
                                .get();
                        final assigneeName =
                            assigneeDoc.data()?['fullName'] ?? 'Không tên';

                        // Tạo taskId mới
                        String taskId =
                            FirebaseFirestore.instance
                                .collection('tasks')
                                .doc()
                                .id;

                        // Lưu task vào Firestore, có thêm assigneeName
                        await FirebaseFirestore.instance
                            .collection('tasks')
                            .doc(taskId)
                            .set({
                              'taskId': taskId,
                              'name': taskController.text.trim(),
                              'projectId': widget.projectId,
                              'processId': widget.processId,
                              'assigneeId': selectedUser,
                              'assigneeName': assigneeName,
                              'createdAt': Timestamp.now(),
                              'status': 'To Do',
                            });

                        // Cập nhật lại danh sách task hiển thị
                        setState(() {});

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
              FutureBuilder<String>(
                future: _getCurrentUserRole(),
                builder: (context, roleSnapshot) {
                  if (!roleSnapshot.hasData) {
                    return Text("Đang tải...");
                  }

                  final role = roleSnapshot.data!;
                  final uid = FirebaseAuth.instance.currentUser!.uid;

                  final query = FirebaseFirestore.instance
                      .collection('tasks')
                      .where('processId', isEqualTo: widget.processId);

                  final filteredQuery =
                      (role == 'employee')
                          ? query.where('assigneeId', isEqualTo: uid)
                          : query;

                  return StreamBuilder<QuerySnapshot>(
                    stream: filteredQuery.snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Text("Đang tải...");
                      }
                      return Text(
                        "Số lượng task: ${snapshot.data!.docs.length}",
                      );
                    },
                  );
                },
              ),

              Expanded(
                child: FutureBuilder<String>(
                  future: _getCurrentUserRole(),
                  builder: (context, roleSnapshot) {
                    if (!roleSnapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    final role = roleSnapshot.data!;
                    final uid = FirebaseAuth.instance.currentUser!.uid;

                    final query = FirebaseFirestore.instance
                        .collection('tasks')
                        .where('projectId', isEqualTo: widget.projectId)
                        .where('processId', isEqualTo: widget.processId);

                    final filteredQuery =
                        (role == 'employee')
                            ? query.where('assigneeId', isEqualTo: uid)
                            : query;

                    return StreamBuilder<QuerySnapshot>(
                      stream: filteredQuery.snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(child: CircularProgressIndicator());
                        }

                        final tasks = snapshot.data!.docs;

                        if (tasks.isEmpty) {
                          return Center(child: Text("Không có task nào"));
                        }

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
                                      child: ListTile(
                                        title: Text(task['name']),
                                      ),
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

Future<bool> _canMoveTaskToStatus(String taskId, String newStatus) async {
  final subtaskSnapshot =
      await FirebaseFirestore.instance
          .collection('subtasks')
          .where('taskId', isEqualTo: taskId)
          .get();

  final subtasks = subtaskSnapshot.docs;

  if (newStatus == 'Doing') {
    // ⚠️ Ít nhất 1 subtask đã ở Doing thì mới cho phép
    return subtasks.isEmpty || subtasks.any((s) => s['status'] == 'Doing');
  }

  if (newStatus == 'Done') {
    return subtasks.isEmpty ||
        subtasks.every(
          (s) => s['status'] == 'Done' || s['status'] == 'Complete',
        );
  }

  if (newStatus == 'Complete') {
    return subtasks.isEmpty || subtasks.every((s) => s['status'] == 'Complete');
  }

  return true;
}
