import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  final List<String> _defaultProcesses = ["To Do", "Doing", "Done", "Complete"];

  Future<void> _createProject() async {
    if (_projectNameController.text.trim().isEmpty ||
        _selectedAssigneeUid == null ||
        _selectedDeadline == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng điền đủ thông tin.')),
      );
      return;
    }

    try {
      final projectRef = await FirebaseFirestore.instance
          .collection('projects')
          .add({
            'name': _projectNameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(), // ✅ CHỈNH Ở ĐÂY
            'assignee': _selectedAssigneeUid,
            'assigneeName': _selectedAssigneeName ?? '',
            'deadline': Timestamp.fromDate(_selectedDeadline!),
            'processes': _defaultProcesses,
            'isCompleted': false,
          });

      await FirebaseFirestore.instance.collection('notifications').add({
        'title': 'Bạn được giao dự án mới',
        'description':
            'Dự án "${_projectNameController.text.trim()}" đã được tạo bởi Admin và giao cho bạn.',
        'timestamp': FieldValue.serverTimestamp(),
        'assigneeId': _selectedAssigneeUid,
        'projectId': projectRef.id,
        'projectName': _projectNameController.text.trim(),
        'isRead': false,
        'type': 'project_assigned',
      });

      for (var process in _defaultProcesses) {
        await projectRef.collection('processes').add({
          'name': process,
          'order': _defaultProcesses.indexOf(process),
        });
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tạo project thành công!')));

      _projectNameController.clear();
      _descriptionController.clear();
      _deadlineController.clear();

      setState(() {
        _selectedAssigneeUid = null;
        _selectedAssigneeName = null;
        _selectedDeadline = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: ${e.toString()}')));
    }
  }

  Future<List<Map<String, String>>> _getUsers() async {
    final snapshot = await FirebaseFirestore.instance.collection('users').get();
    return snapshot.docs.map((doc) {
      return {
        'uid': doc.id,
        'fullName': (doc['fullName'] ?? 'No Name').toString(),
        'email': (doc['email'] ?? '').toString(),
      };
    }).toList();
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final picked = await showDatePicker(
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tạo Dự Án'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("Thông tin dự án", style: theme.textTheme.headlineSmall),
            const SizedBox(height: 20),

            _buildSectionCard(
              children: [
                _buildTextField(
                  _projectNameController,
                  'Tên Dự Án',
                  icon: Icons.title,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  _descriptionController,
                  'Mô tả',
                  icon: Icons.description,
                ),
                const SizedBox(height: 16),

                FutureBuilder<List<Map<String, String>>>(
                  future: _getUsers(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedAssigneeUid,
                      decoration: InputDecoration(
                        labelText: "Người thực hiện",
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onChanged: (newValue) {
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
                              ),
                            );
                          }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _deadlineController,
                  readOnly: true,
                  onTap: () => _selectDeadline(context),
                  decoration: InputDecoration(
                    labelText: 'Hạn chót',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              onPressed: _createProject,
              icon: const Icon(Icons.check_circle),
              label: const Text('Tạo Project'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
