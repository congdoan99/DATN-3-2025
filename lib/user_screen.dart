import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poro_2/ProjectDetailScreen.dart';

class UserScreen extends StatefulWidget {
  @override
  _UserScreenState createState() => _UserScreenState();
}

class _UserScreenState extends State<UserScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  Map<String, dynamic>? _userData;
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() async {
    _user = _auth.currentUser;
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

  void _logout() async {
    // Hiển thị hộp thoại xác nhận
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Xác nhận đăng xuất"),
          content: Text("Bạn có chắc chắn muốn đăng xuất không?"),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Trả về false khi nhấn 'Hủy'
              },
              child: Text("Hủy"),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(true); // Trả về true khi nhấn 'Đồng ý'
              },
              child: Text("Đồng ý"),
            ),
          ],
        );
      },
    );

    // Nếu người dùng đồng ý đăng xuất, thực hiện đăng xuất
    if (confirmLogout == true) {
      await _auth.signOut();
      if (mounted) context.go('/auth_gate');
    }
  }

  /// Stream để lấy danh sách project theo quyền hạn
  Stream<QuerySnapshot> getProjectsStream() {
    if (_userData?['role'] == 'manager') {
      return _firestore
          .collection('projects')
          .snapshots(); // Quản lý thấy tất cả các project
    } else {
      return _firestore
          .collection('tasks')
          .where(
            'assigneeId',
            isEqualTo: _user?.uid,
          ) // Lọc các task của nhân viên A
          .snapshots()
          .asyncExpand((taskSnapshot) async* {
            List<String> projectIds =
                taskSnapshot.docs
                    .map((task) => task['projectId'] as String)
                    .toSet()
                    .toList();

            if (projectIds.isEmpty) {
              yield* Stream<
                QuerySnapshot
              >.empty(); // Không có project nào nếu không có task
              return;
            }

            // Trả về danh sách project mà nhân viên A tham gia vào
            yield* _firestore
                .collection('projects')
                .where(FieldPath.documentId, whereIn: projectIds)
                .snapshots();
          });
    }
  }

  /// Stream để lấy danh sách task theo quyền hạn
  Stream<QuerySnapshot> getTasksStream() {
    if (_selectedProjectId == null) {
      return Stream<QuerySnapshot>.empty(); // Không có project nào được chọn
    }

    if (_userData?['role'] == 'manager') {
      return _firestore
          .collection('tasks')
          .where('projectId', isEqualTo: _selectedProjectId)
          .snapshots(); // Quản lý thấy tất cả task của project
    } else {
      return _firestore
          .collection('tasks')
          .where('projectId', isEqualTo: _selectedProjectId)
          .where(
            'assigneeId',
            isEqualTo: _user?.uid,
          ) // Lọc task theo assigneeId của nhân viên
          .snapshots();
    }
  }

  // Hàm trả về màu dựa vào trạng thái task
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User'),
        actions: [IconButton(icon: Icon(Icons.logout), onPressed: _logout)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Account Section
              Text(
                "My Account",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  context.go('/profile_user', extra: _userData);
                },
                child: Row(
                  children: [
                    Icon(Icons.account_circle, size: 40, color: Colors.blue),
                    SizedBox(width: 10),
                    Text(
                      _userData?['email'] ?? _user?.email ?? 'Không có email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),

              // Project and Task Section
              Text(
                "My Projects & Tasks",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  // Project List (Left side)
                  Expanded(
                    flex: 1,
                    child: StreamBuilder<QuerySnapshot>(
                      stream:
                          _userData?['role'] == 'manager'
                              ? _firestore
                                  .collection('projects')
                                  .snapshots() // Quản lý thấy tất cả project
                              : _firestore
                                  .collection('tasks')
                                  .where(
                                    'assigneeId',
                                    isEqualTo: _user?.uid,
                                  ) // Lọc task theo assigneeId của nhân viên
                                  .snapshots()
                                  .asyncExpand((taskSnapshot) async* {
                                    // Lấy danh sách projectId mà nhân viên A có task
                                    List<String> projectIds =
                                        taskSnapshot.docs
                                            .map(
                                              (task) =>
                                                  task['projectId'] as String,
                                            )
                                            .toSet()
                                            .toList();

                                    if (projectIds.isEmpty) {
                                      yield* Stream<
                                        QuerySnapshot
                                      >.empty(); // Không có project nào nếu không có task
                                      return;
                                    }

                                    // Trả về danh sách project mà nhân viên A tham gia vào
                                    yield* _firestore
                                        .collection('projects')
                                        .where(
                                          FieldPath.documentId,
                                          whereIn: projectIds,
                                        )
                                        .snapshots();
                                  }),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(child: Text("Không có project nào."));
                        }

                        var projects = snapshot.data!.docs;

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: projects.length,
                          itemBuilder: (context, index) {
                            var projectData =
                                projects[index].data() as Map<String, dynamic>;
                            String projectId = projects[index].id;

                            return Card(
                              child: ListTile(
                                title: Text(
                                  projectData['name'] ?? 'Unnamed Project',
                                ),
                                subtitle: Text(
                                  "Người thực hiện: ${projectData['assignee'] ?? 'Chưa có người thực hiện'}",
                                ),
                                leading: Icon(Icons.folder, color: Colors.blue),
                                trailing: IconButton(
                                  icon: Icon(Icons.list, color: Colors.green),
                                  onPressed: () {
                                    setState(() {
                                      _selectedProjectId = projectId;
                                    });
                                  },
                                ),
                                onTap: () {
                                  // Chuyển sang màn ProjectDetailScreen khi nhấn vào project
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => ProjectDetailScreen(
                                            projectId: projectId,
                                            projectName:
                                                projectData['name'] ?? '',
                                          ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  SizedBox(width: 16),
                  // Task List (Right side)
                  Expanded(
                    flex: 1,
                    child: StreamBuilder<QuerySnapshot>(
                      stream:
                          getTasksStream(), // Sử dụng stream mới lọc theo user
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text("Không có task nào cho bạn."),
                          );
                        }

                        var tasks = snapshot.data!.docs;

                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: tasks.length,
                          itemBuilder: (context, index) {
                            var taskData =
                                tasks[index].data() as Map<String, dynamic>;
                            return Card(
                              child: ListTile(
                                title: Text(taskData['name'] ?? 'Unnamed Task'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Trạng thái: ${taskData['status'] ?? 'Chưa có trạng thái'}",
                                      style: TextStyle(
                                        color: _getTaskColor(
                                          taskData['status'] ?? '',
                                        ),
                                      ),
                                    ),
                                    Text(
                                      "Người thực hiện: ${taskData['assignee'] ?? 'Chưa có'}",
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  ],
                                ),
                                leading: Icon(
                                  Icons.task,
                                  color: _getTaskColor(
                                    taskData['status'] ?? '',
                                  ),
                                ),
                                onTap: () {
                                  // Mở màn hình chi tiết task (nếu cần)
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
