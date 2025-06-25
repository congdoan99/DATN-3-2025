import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh Sách Dự Án'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go(
              '/admin',
            ); // hoặc route tương ứng huynh dùng cho AdminScreen
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tạo dự án mới',
            onPressed: () async {
              final result = await context.push('/create_project');

              if (result == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tạo dự án thành công')),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('projects')
                .where('isCompleted', isEqualTo: false)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Không có dự án nào.'));
          }

          final projects = snapshot.data!.docs;

          return ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final doc = projects[index];
              final name = doc['name'] ?? 'Chưa đặt tên';
              final description = doc['description'] ?? '';
              final createdAt = (doc['createdAt'] as Timestamp?)?.toDate();

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.folder_open, color: Colors.white),
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      final projectId = doc.id;

                      if (value == 'edit') {
                        final nameController = TextEditingController(
                          text: doc['name'],
                        );
                        final descController = TextEditingController(
                          text: doc['description'],
                        );

                        showDialog(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Chỉnh sửa dự án'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextField(
                                      controller: nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Tên dự án',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: descController,
                                      decoration: const InputDecoration(
                                        labelText: 'Mô tả',
                                      ),
                                      maxLines: 3,
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final newName =
                                          nameController.text.trim();
                                      final newDesc =
                                          descController.text.trim();

                                      if (newName.isEmpty) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Tên không được để trống',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      await FirebaseFirestore.instance
                                          .collection('projects')
                                          .doc(doc.id)
                                          .update({
                                            'name': newName,
                                            'description': newDesc,
                                          });

                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Cập nhật thành công',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('Lưu'),
                                  ),
                                ],
                              ),
                        );
                      } else if (value == 'delete') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Xác nhận'),
                                content: const Text(
                                  'Bạn có chắc muốn ẩn dự án này không?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(false),
                                    child: const Text('Hủy'),
                                  ),
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(context).pop(true),
                                    child: const Text('Đồng ý'),
                                  ),
                                ],
                              ),
                        );

                        if (confirm == true) {
                          await FirebaseFirestore.instance
                              .collection('projects')
                              .doc(projectId)
                              .update({'isCompleted': true});

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Dự án đã được ẩn')),
                            );
                          }
                        }
                      }
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Sửa'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Xóa'),
                          ),
                        ],
                  ),
                  onTap: () {
                    final projectId = doc.id;
                    final projectName = doc['name'] ?? 'Chưa đặt tên';

                    context.go('/project/$projectId', extra: projectName);
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
