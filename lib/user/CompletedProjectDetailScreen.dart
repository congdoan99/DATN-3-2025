import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CompletedProjectDetailScreen extends StatelessWidget {
  final String projectId;
  final String projectName;

  const CompletedProjectDetailScreen({
    required this.projectId,
    required this.projectName,
  });

  // Hàm lấy thông tin các task trong project
  Future<List<Map<String, dynamic>>> fetchProjectTasks() async {
    final firestore = FirebaseFirestore.instance;

    // Lấy tất cả các task của project
    final taskSnap =
        await firestore
            .collection('tasks')
            .where('projectId', isEqualTo: projectId)
            .get();

    List<Map<String, dynamic>> tasks = [];

    for (final task in taskSnap.docs) {
      final taskData = task.data();
      tasks.add({
        'id': task.id,
        'name': taskData['name'] ?? 'Chưa đặt tên',
        'status': taskData['status'] ?? 'Chưa có trạng thái',
      });
    }

    return tasks;
  }

  // Hàm lấy thông tin người thực hiện
  Future<String> fetchAssigneeName() async {
    final firestore = FirebaseFirestore.instance;

    final projectDoc =
        await firestore.collection('projects').doc(projectId).get();
    final projectData = projectDoc.data();
    final assigneeId = projectData?['assigneeId'];

    if (assigneeId != null && assigneeId.isNotEmpty) {
      final userDoc = await firestore.collection('users').doc(assigneeId).get();
      final userData = userDoc.data();
      return userData?['displayName'] ?? 'Không rõ';
    } else {
      return 'Không rõ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(projectName)),
      body: FutureBuilder(
        future: Future.wait([fetchAssigneeName(), fetchProjectTasks()]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return Center(child: Text('Không có dữ liệu.'));
          }

          final assigneeName = snapshot.data![0] as String;
          final tasks = snapshot.data![1] as List<Map<String, dynamic>>;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tên dự án: $projectName',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 8),
                Text('Người thực hiện: $assigneeName'),
                SizedBox(height: 16),
                Text(
                  'Danh sách các task:',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 8),
                if (tasks.isEmpty)
                  Text('Không có task nào trong dự án này.')
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return ListTile(
                          title: Text(task['name']),
                          subtitle: Text('Trạng thái: ${task['status']}'),
                          leading: Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
