import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      return const Scaffold(body: Center(child: Text('Chưa đăng nhập')));
    }

    final notificationStream =
        FirebaseFirestore.instance
            .collection('notifications')
            .where('assigneeId', isEqualTo: currentUid)
            .orderBy('timestamp', descending: true)
            .snapshots();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/user_screen'),
        ),
        title: const Text('Thông báo'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notificationStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print("🔥 Lỗi khi tải thông báo: ${snapshot.error}");
            return const Center(child: Text('Lỗi khi tải thông báo.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Không có thông báo.'));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final docId = doc.id;
              final title = data['title'] ?? 'Không có tiêu đề';
              final description = data['description'] ?? '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.notifications_active,
                    color: Colors.blue,
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(description),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder:
                            (_) => AlertDialog(
                              title: const Text('Xác nhận xóa'),
                              content: const Text(
                                'Huynh có chắc muốn xóa thông báo này không?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, false),
                                  child: const Text('Hủy'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                      );

                      if (confirm == true) {
                        await FirebaseFirestore.instance
                            .collection('notifications')
                            .doc(docId)
                            .delete();
                      }
                    },
                  ),
                  onTap: () async {
                    final taskId = data['taskId'];
                    final projectId = data['projectId'];

                    // Lấy role của người dùng hiện tại
                    final userDoc =
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUid)
                            .get();
                    final role = userDoc.data()?['role'];

                    if (role == 'manager' && projectId != null) {
                      // Lấy tên dự án để truyền sang ProjectDetailScreen
                      final projectDoc =
                          await FirebaseFirestore.instance
                              .collection('projects')
                              .doc(projectId)
                              .get();

                      final projectName =
                          projectDoc.data()?['name'] ?? 'Không rõ tên dự án';

                      // Chuyển màn hình đến ProjectDetailScreen
                      context.go(
                        '/project_detail/$projectId',
                        extra: {'projectName': projectName},
                      );
                    } else if (taskId != null) {
                      context.go('/task_detail/$taskId');
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Không tìm thấy nội dung công việc.'),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
