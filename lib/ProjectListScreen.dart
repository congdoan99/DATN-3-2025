import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProjectListScreen extends StatefulWidget {
  const ProjectListScreen({super.key});

  @override
  State<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends State<ProjectListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    _tabController = TabController(length: 2, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh Sách Dự Án'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/admin');
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Đang hoạt động'), Tab(text: 'Đã hoàn thành')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Tạo dự án mới',
            onPressed: () async {
              final result = await context.pushNamed('create_project');
              if (result == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tạo dự án thành công')),
                );
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProjectList(false), // Đang hoạt động
          _buildProjectList(true), // Đã hoàn thành
        ],
      ),
    );
  }

  Widget _buildProjectList(bool isCompleted) {
    final query = FirebaseFirestore.instance.collection('projects');

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('Không có dữ liệu.'));
        }

        final allDocs = snapshot.data!.docs;

        final filteredProjects =
            allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'];
              final isVisible = data['isVisible'] ?? true;

              if (!isVisible) return false;

              return isCompleted ? status == 'Complete' : status != 'Complete';
            }).toList();

        if (filteredProjects.isEmpty) {
          return Center(
            child: Text(
              isCompleted
                  ? 'Không có dự án đã hoàn thành.'
                  : 'Không có dự án nào.',
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredProjects.length,
          itemBuilder: (context, index) {
            final doc = filteredProjects[index];
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? 'Chưa đặt tên';
            final description = data['description'] ?? '';
            final projectId = doc.id;

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
                trailing:
                    isCompleted
                        ? null
                        : PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'edit') {
                              final nameController = TextEditingController(
                                text: data['name'],
                              );
                              final descController = TextEditingController(
                                text: data['description'],
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
                                          onPressed:
                                              () => Navigator.pop(context),
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
                            } else if (value == 'hide') {
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
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: const Text('Hủy'),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          child: const Text('Xác nhận'),
                                        ),
                                      ],
                                    ),
                              );

                              if (confirm == true) {
                                await FirebaseFirestore.instance
                                    .collection('projects')
                                    .doc(projectId)
                                    .update({'isVisible': false});

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Dự án đã được ẩn'),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          itemBuilder:
                              (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Sửa'),
                                ),
                                PopupMenuItem(
                                  value: 'hide',
                                  child: Text('Xóa ẩn'),
                                ),
                              ],
                        ),
                onTap: () {
                  context.go('/project/$projectId', extra: name);
                },
              ),
            );
          },
        );
      },
    );
  }
}
