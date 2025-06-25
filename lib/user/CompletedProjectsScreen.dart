import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CompletedProjectsScreen extends StatelessWidget {
  const CompletedProjectsScreen({super.key});

  Future<List<Map<String, dynamic>>> fetchCompletedProjects() async {
    final firestore = FirebaseFirestore.instance;
    final projectsSnapshot = await firestore.collection('projects').get();

    final completedProjects = <Map<String, dynamic>>[];

    for (final projectDoc in projectsSnapshot.docs) {
      final projectId = projectDoc.id;
      final projectData = projectDoc.data();

      final tasksSnapshot =
          await firestore
              .collection('tasks')
              .where('projectId', isEqualTo: projectId)
              .get();

      final allTasksComplete =
          tasksSnapshot.docs.isNotEmpty &&
          tasksSnapshot.docs.every((doc) => doc['status'] == 'Complete');

      if (!allTasksComplete) continue;

      if (projectData['status'] != 'Complete') {
        await firestore.collection('projects').doc(projectId).update({
          'status': 'Complete',
        });
      }

      completedProjects.add({
        'id': projectId,
        'name': projectData['name'] ?? 'Chưa đặt tên',
        'assigneeName': projectData['assigneeName'] ?? 'Không rõ',
      });
    }

    return completedProjects;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/user_screen'),
        ),
        title: const Text('Dự Án Đã Hoàn Thành'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchCompletedProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final projects = snapshot.data ?? [];

          if (projects.isEmpty) {
            return const Center(child: Text('Chưa có dự án nào hoàn thành.'));
          }

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return ListTile(
                title: Text(project['name']),
                subtitle: Text('Người thực hiện: ${project['assigneeName']}'),
                leading: const Icon(Icons.check_circle, color: Colors.green),
                onTap:
                    () => context.go(
                      '/completed-project-detail/${project['id']}',
                    ),
              );
            },
          );
        },
      ),
    );
  }
}
