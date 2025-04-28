import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';

class AdminProjectScreen extends StatefulWidget {
  const AdminProjectScreen({super.key});

  @override
  _AdminProjectScreenState createState() => _AdminProjectScreenState();
}

class _AdminProjectScreenState extends State<AdminProjectScreen> {
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();

  String? _selectedAssigneeUid;
  String? _selectedAssigneeName;
  DateTime? _selectedDeadline;
  List<String> _selectedProcesses = [];

  final List<String> _availableProcesses = [
    "To Do",
    "Doing",
    "Done",
    "Complete",
  ];

  Future<void> _createProject() async {
    if (_projectNameController.text.trim().isEmpty ||
        _selectedAssigneeUid == null ||
        _selectedDeadline == null ||
        _selectedProcesses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Vui lòng điền đủ thông tin.')));
      return;
    }

    try {
      String projectName = _projectNameController.text.trim();
      String description = _descriptionController.text.trim();
      String assigneeUid = _selectedAssigneeUid!;
      String assigneeName = _selectedAssigneeName ?? '';
      DateTime deadline = _selectedDeadline!;

      var projectRef = await FirebaseFirestore.instance
          .collection('projects')
          .add({
            'name': projectName,
            'description': description,
            'createdAt': Timestamp.now(),
            'assignee': assigneeUid,
            'assigneeName': assigneeName,
            'deadline': Timestamp.fromDate(deadline),
            'processes': _selectedProcesses,
          });

      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'Bạn đã được giao một dự án mới',
        'description':
            'Dự án "$projectName" đã được giao cho bạn với hạn chót ${deadline.toLocal().toString().split(' ')[0]}',
        'timestamp': Timestamp.now(),
        'assignee': assigneeUid,
        'isRead': false,
      });

      for (var process in _selectedProcesses) {
        await projectRef.collection('processes').add({
          'name': process,
          'order': _availableProcesses.indexOf(process),
        });
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Tạo project thành công!')));
      _projectNameController.clear();
      _descriptionController.clear();
      _deadlineController.clear();
      setState(() {
        _selectedAssigneeUid = null;
        _selectedAssigneeName = null;
        _selectedDeadline = null;
        _selectedProcesses = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  Future<List<Map<String, String>>> _getUsers() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('users').get();
    return snapshot.docs.map((doc) {
      return {
        'uid': doc.id,
        'fullName': (doc['fullName'] ?? 'No Name').toString(),
        'email': (doc['email'] ?? '').toString(),
      };
    }).toList();
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedDeadline = picked;
        _deadlineController.text = "${picked.toLocal()}".split(' ')[0];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý Project'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _projectNameController,
              decoration: InputDecoration(labelText: 'Tên Project'),
            ),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Mô tả Project'),
            ),
            FutureBuilder<List<Map<String, String>>>(
              future: _getUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return DropdownButtonFormField<String>(
                  value: _selectedAssigneeUid,
                  decoration: InputDecoration(
                    labelText: "Người thực hiện",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String? newValue) {
                    final selectedUser = snapshot.data!.firstWhere(
                      (user) => user['uid'] == newValue,
                    );
                    setState(() {
                      _selectedAssigneeUid = newValue;
                      _selectedAssigneeName = selectedUser['fullName'];
                    });
                  },
                  items:
                      snapshot.data!.map((user) {
                        return DropdownMenuItem<String>(
                          value: user['uid'],
                          child: Text(
                            "${user['fullName']} (${user['email']})",
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                );
              },
            ),
            TextFormField(
              controller: _deadlineController,
              decoration: InputDecoration(labelText: 'Hạn chót'),
              readOnly: true,
              onTap: () => _selectDeadline(context),
            ),
            SizedBox(height: 10),
            MultiSelectDialogField(
              items:
                  _availableProcesses
                      .map((e) => MultiSelectItem(e, e))
                      .toList(),
              title: Text("Chọn Process"),
              selectedColor: Colors.blue,
              buttonText: Text("Chọn Process"),
              onConfirm:
                  (values) => setState(
                    () => _selectedProcesses = List<String>.from(values),
                  ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _createProject,
              child: Text('Tạo Project'),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('projects')
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text('Không có project nào.'));
                  }
                  var projects = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: projects.length,
                    itemBuilder: (context, index) {
                      var doc = projects[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 8),
                        elevation: 3,
                        child: ListTile(
                          title: Text(
                            doc['name'] ?? 'No Name',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Người thực hiện: ${doc['assigneeName'] ?? 'Không có'}\n'
                            'Hạn chót: ${doc['deadline']?.toDate()?.toString().split(' ')[0] ?? 'Không có'}',
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 18),
                          onTap: () {
                            context.go(
                              '/project-detail/${doc.id}/${Uri.encodeComponent(doc['name'] ?? '')}',
                            );
                          },
                        ),
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
