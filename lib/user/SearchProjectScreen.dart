import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchProjectScreen extends StatefulWidget {
  const SearchProjectScreen({super.key});

  @override
  State<SearchProjectScreen> createState() => _SearchProjectScreenState();
}

class _SearchProjectScreenState extends State<SearchProjectScreen> {
  final TextEditingController _controller = TextEditingController();
  String _searchText = "";
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _searchFuture;
  Timer? _debounce;

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _searchText = "";
      _searchFuture = null;
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchProjects(
    String text,
  ) async {
    final lowerText = text.toLowerCase();

    final query = FirebaseFirestore.instance
        .collection('projects')
        .orderBy('createdAt', descending: true)
        .limit(200);

    final snapshot = await query.get();

    return snapshot.docs.where((doc) {
      final name = (doc.data()['name'] ?? '').toString().toLowerCase();
      return name.contains(lowerText);
    }).toList();
  }

  void _onSearchChanged(String val) {
    final trimmed = val.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchText = trimmed;
        _searchFuture = trimmed.isNotEmpty ? _fetchProjects(trimmed) : null;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm Project'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/user_screen'),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchInput(),
            const SizedBox(height: 16),
            Expanded(child: _buildProjectList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return TextField(
      controller: _controller,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Nhập từ khóa...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon:
            _searchText.isNotEmpty
                ? GestureDetector(
                  onTap: _clearSearch,
                  child: const Icon(Icons.clear),
                )
                : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onChanged: _onSearchChanged,
    );
  }

  Widget _buildProjectList() {
    if (_searchText.isEmpty) {
      return const Center(
        child: Text(
          'Nhập từ khóa để tìm project',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _searchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final projects = snapshot.data ?? [];

        if (projects.isEmpty) {
          return const Center(child: Text('Không tìm thấy project nào'));
        }

        return ListView.separated(
          itemCount: projects.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final doc = projects[index];
            final data = doc.data();
            final id = doc.id;
            final name = data['name'] ?? 'Unnamed Project';
            final status = data['status'] ?? '';

            return ProjectListItem(
              projectId: id,
              projectName: name,
              status: status,
              onTap: () {
                if (status == 'Complete') {
                  context.push(
                    '/completed-project-detail/$id',
                    extra: {'from': 'search'}, // hoặc 'completedList'
                  );
                } else {
                  context.go(
                    '/project-detail/$id/${Uri.encodeComponent(name)}',
                    extra: {'from': 'search'},
                  );
                }
              },
            );
          },
        );
      },
    );
  }
}

class ProjectListItem extends StatelessWidget {
  final String projectId;
  final String projectName;
  final String status;
  final VoidCallback onTap;

  const ProjectListItem({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(projectName),
      subtitle: Text(
        status == 'Complete' ? 'Đã hoàn thành' : 'Chưa hoàn thành',
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
