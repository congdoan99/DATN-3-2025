import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CompletedProjectsScreen extends StatelessWidget {
  const CompletedProjectsScreen({super.key});

  Future<List<Map<String, dynamic>>> fetchCompletedProjects() async {
    final firestore = FirebaseFirestore.instance;

    final snapshot = await firestore.collection('projects').get();
    final projects = snapshot.docs;

    List<Map<String, dynamic>> completedProjects = [];

    for (final project in projects) {
      final taskSnap =
          await firestore
              .collection('tasks')
              .where('projectId', isEqualTo: project.id)
              .get();

      final isComplete =
          taskSnap.docs.isNotEmpty &&
          taskSnap.docs.every((doc) => doc['status'] == 'Complete');

      if (isComplete) {
        final projectData = project.data();
        final assigneeId = projectData['assigneeId'];

        // Cập nhật trạng thái dự án nếu tất cả task đã hoàn thành
        await firestore.collection('projects').doc(project.id).update({
          'status': 'Complete', // Cập nhật trạng thái của dự án
        });

        String assigneeName = 'Không rõ';

        // Nếu có assigneeId, fetch thông tin người thực hiện
        if (assigneeId != null && assigneeId.isNotEmpty) {
          final userDoc =
              await firestore.collection('users').doc(assigneeId).get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            assigneeName = userData?['displayName'] ?? 'Không rõ';
          }
        }

        completedProjects.add({
          'id': project.id,
          'name': projectData['name'] ?? 'Chưa đặt tên',
          'assigneeName': assigneeName,
        });
      }
    }

    return completedProjects;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Project đã hoàn thành')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchCompletedProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('Chưa có project nào hoàn thành.'));
          }

          final projects = snapshot.data!;

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              final projectId = project['id'];
              final projectName = project['name'];
              final assigneeName = project['assigneeName'];

              return ListTile(
                title: Text(projectName),
                subtitle: Text('Người thực hiện: $assigneeName'),
                leading: Icon(Icons.check_circle, color: Colors.green),
                onTap: () {
                  context.go('/completed-project-detail/${project['id']}');
                },
              );
            },
          );
        },
      ),
    );
  }
}
