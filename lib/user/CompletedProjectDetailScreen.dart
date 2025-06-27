import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    // Lấy thông tin từ màn trước
    final extra = GoRouterState.of(context).extra;
    String? fromScreen;
    if (extra is Map<String, dynamic>) {
      fromScreen = extra['from'] as String?;
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (fromScreen == 'search') {
              context.go('/search-project');
            } else {
              context.go('/completed-projects');
            }
          },
        ),
        title: const Text('📁 Chi tiết Dự án'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchProjectDetail(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('Không tìm thấy dữ liệu.'));
          }

          final project = snapshot.data!['project'] ?? {};
          final tasks = snapshot.data!['tasks'] ?? [];

          return Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                Text(
                  '📌 Tên dự án:',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  project['name'] ?? 'Chưa đặt tên',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                Text(
                  '👤 Người thực hiện:',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  project['assigneeName'] ?? 'Không rõ',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  '📆 Hạn chót:',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  project['deadline']?.toDate().toString().split(' ')[0] ??
                      'Không có',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Text(
                  '📄 Mô tả:',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  project['description'] ?? 'Không có mô tả',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                Text(
                  '📋 Danh sách công việc:',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...tasks.map<Widget>((task) {
                  final taskName = task['name'] ?? 'Không rõ tên công việc';
                  final taskStatus = task['status'] ?? 'Chưa rõ trạng thái';

                  final completedAt =
                      task['completedAt'] != null
                          ? (task['completedAt'] as Timestamp).toDate()
                          : null;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 2,
                    child: ListTile(
                      leading: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                      title: Text(
                        taskName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '[$taskStatus]',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          Text(
                            '👷 Người thực hiện: ${task['assigneeName'] ?? 'Không rõ'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                          if (completedAt != null)
                            Text(
                              '✅ Hoàn thành: ${completedAt.toString().split(' ')[0]}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
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
