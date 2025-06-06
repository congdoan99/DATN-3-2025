import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CompletedProjectDetailScreen extends StatelessWidget {
  final String projectId;

  const CompletedProjectDetailScreen({super.key, required this.projectId});

  Future<Map<String, dynamic>> fetchProjectDetail() async {
    final projectDoc =
        await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .get();

    final projectData = projectDoc.data() ?? {};

    final taskSnap =
        await FirebaseFirestore.instance
            .collection('tasks')
            .where('projectId', isEqualTo: projectId)
            .get();

    final tasks = taskSnap.docs.map((doc) => doc.data()).toList();

    return {'project': projectData, 'tasks': tasks};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chi tiết Project')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchProjectDetail(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return Center(child: Text('Không tìm thấy dữ liệu.'));
          }

          final project = snapshot.data!['project'] ?? {};
          final tasks = snapshot.data!['tasks'] ?? [];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                Text(
                  '📌 Tên: ${project['name'] ?? 'Chưa đặt'}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                SizedBox(height: 8),
                Text(
                  '👤 Người thực hiện: ${project['assigneeName'] ?? 'Không rõ'}',
                ),
                SizedBox(height: 4),
                Text(
                  '📆 Hạn chót: ${project['deadline']?.toDate().toString().split(' ')[0] ?? 'Không có'}',
                ),
                SizedBox(height: 8),
                Text(
                  '📄 Mô tả:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(project['description'] ?? 'Không có mô tả'),
                SizedBox(height: 16),
                Text(
                  '📋 Danh sách công việc:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...tasks.map<Widget>((task) {
                  final taskName = task['name'] ?? 'Không rõ tên công việc';
                  final taskStatus = task['status'] ?? 'Chưa rõ trạng thái';

                  return ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text(taskName),
                    subtitle: Text('[$taskStatus]'),
                  );
                }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }
}
