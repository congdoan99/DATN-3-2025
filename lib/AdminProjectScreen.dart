import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:poro_2/ProjectDetailScreen.dart';

class AdminProjectScreen extends StatefulWidget {
  @override
  _AdminProjectScreenState createState() => _AdminProjectScreenState();
}

class _AdminProjectScreenState extends State<AdminProjectScreen> {
  final TextEditingController _projectNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _deadlineController = TextEditingController();

  String? _selectedAssignee;
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
        _selectedAssignee == null ||
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
      String assignee = _selectedAssignee!;
      DateTime deadline = _selectedDeadline!;

      var projectRef = await FirebaseFirestore.instance
          .collection('projects')
          .add({
            'name': projectName,
            'description': description,
            'createdAt': Timestamp.now(),
            'assignee': assignee,
            'deadline': Timestamp.fromDate(deadline),
            'processes': _selectedProcesses,
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
      setState(() {
        _selectedAssignee = null;
        _selectedDeadline = null;
        _selectedProcesses = [];
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  Future<List<String>> _getUsers() async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('users').get();
    return snapshot.docs.map((doc) {
      String fullName = doc['fullName'] ?? 'No Name';
      String email = doc['email'] ?? '';
      return '$fullName ($email)';
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
      appBar: AppBar(title: Text('Quản lý Project')),
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
            FutureBuilder<List<String>>(
              future: _getUsers(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return DropdownButtonFormField<String>(
                  value: _selectedAssignee,
                  decoration: InputDecoration(
                    labelText: "Người thực hiện",
                    border: OutlineInputBorder(),
                  ),
                  onChanged:
                      (String? newValue) =>
                          setState(() => _selectedAssignee = newValue),
                  items:
                      snapshot.data!.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
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
                            'Người thực hiện: ${doc['assignee'] ?? 'Không có'}\n'
                            'Hạn chót: ${doc['deadline']?.toDate()?.toString().split(' ')[0] ?? 'Không có'}',
                          ),
                          trailing: Icon(Icons.arrow_forward_ios, size: 18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => ProjectDetailScreen(
                                      projectId: doc.id,
                                      projectName: doc['name'],
                                    ),
                              ),
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
