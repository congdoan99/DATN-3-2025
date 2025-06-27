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
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProjectList(
            false,
          ), // Dự án đang hoạt động (không có status hoặc khác "Complete")
          _buildProjectList(true), // Dự án đã hoàn thành (status == "Complete")
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
          return Center(child: Text('Không có dữ liệu.'));
        }

        final allDocs = snapshot.data!.docs;

        final filteredProjects =
            allDocs.where((doc) {
              final hasStatus = doc.data().toString().contains('status');
              final status = hasStatus ? doc['status'] : null;
              return isCompleted
                  ? status == 'Complete'
                  : status == null || status != 'Complete';
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
            final name = doc['name'] ?? 'Chưa đặt tên';
            final description = doc['description'] ?? '';
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
                            } else if (value == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: const Text('Xác nhận'),
                                      content: const Text(
                                        'Bạn có chắc muốn hoàn thành dự án này không?',
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
                                          child: const Text('Đồng ý'),
                                        ),
                                      ],
                                    ),
                              );

                              if (confirm == true) {
                                await FirebaseFirestore.instance
                                    .collection('projects')
                                    .doc(projectId)
                                    .update({'status': 'Complete'});

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Dự án đã được hoàn thành'),
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
                                  value: 'delete',
                                  child: Text('Hoàn thành'),
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
