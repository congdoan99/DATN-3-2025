import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SearchProjectScreen extends StatefulWidget {
  @override
  _SearchProjectScreenState createState() => _SearchProjectScreenState();
}

class _SearchProjectScreenState extends State<SearchProjectScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TextEditingController _controller = TextEditingController();
  String _searchText = "";

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _searchText = "";
    });
  }

  Stream<QuerySnapshot> _searchProjectsStream() {
    if (_searchText.isEmpty) {
      return Stream.value(
        Stream<QuerySnapshot>.empty() as QuerySnapshot<Object?>,
      ); // Trả về stream rỗng khi chưa search (cần tạo fake nếu muốn tránh lỗi)
    }

    // Firestore không hỗ trợ tìm kiếm text đầy đủ, nên dùng query khoảng isGreaterThanOrEqualTo, isLessThanOrEqualTo để tìm prefix
    return _firestore
        .collection('projects')
        .where(
          'name',
          isGreaterThanOrEqualTo: _searchText,
          isLessThanOrEqualTo: _searchText + '\uf8ff',
        )
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tìm kiếm Project'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/user_screen'),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Nhập từ khóa...',
                prefixIcon: Icon(Icons.search),
                suffixIcon:
                    _searchText.isNotEmpty
                        ? GestureDetector(
                          onTap: _clearSearch,
                          child: Icon(Icons.clear),
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchText = val.trim();
                });
              },
            ),
            SizedBox(height: 16),
            Expanded(
              child:
                  _searchText.isEmpty
                      ? Center(
                        child: Text(
                          'Nhập từ khóa để tìm project',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                      : StreamBuilder<QuerySnapshot>(
                        stream: _searchProjectsStream(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (!snapshot.hasData ||
                              snapshot.data!.docs.isEmpty) {
                            return Center(
                              child: Text('Không tìm thấy project nào'),
                            );
                          }

                          var projects = snapshot.data!.docs;

                          return ListView.separated(
                            itemCount: projects.length,
                            separatorBuilder: (context, index) => Divider(),
                            itemBuilder: (context, index) {
                              var projectData =
                                  projects[index].data()
                                      as Map<String, dynamic>;
                              String projectId = projects[index].id;
                              String projectName =
                                  projectData['name'] ?? 'Unnamed Project';

                              return ListTile(
                                title: Text(projectName),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  size: 16,
                                ),
                                onTap: () {
                                  // Đóng màn tìm kiếm và chuyển sang màn chi tiết project
                                  Navigator.of(context).pop();
                                  // Hoặc nếu dùng GoRouter:
                                  // context.go('/project-detail/$projectId/${Uri.encodeComponent(projectName)}');
                                },
                              );
                            },
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
