import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CreateTaskScreen extends StatefulWidget {
  @override
  _CreateTaskScreenState createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  String? selectedProjectId;
  String? selectedAssigneeId;
  DateTime? dueDate;
  String? processId;

  List<Map<String, String>> projects = [];
  List<Map<String, String>> assignees = [];

  TextEditingController taskNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchProjects();
    fetchAssignees();
  }

  Future<void> fetchProjects() async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('projects').get();
      setState(() {
        projects =
            snapshot.docs
                .map((doc) => {'id': doc.id, 'name': doc['name'] as String})
                .toList();
      });
    } catch (e) {
      print("Lỗi khi lấy danh sách project: $e");
    }
  }

  Future<void> fetchAssignees() async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('users').get();
      setState(() {
        assignees =
            snapshot.docs
                .map((doc) => {'id': doc.id, 'name': doc['fullName'] as String})
                .toList();
      });
    } catch (e) {
      print("Lỗi khi lấy danh sách người dùng: $e");
    }
  }

  Future<String?> fetchHighestPriorityProcessIdBasedOnProject(
    String projectId,
  ) async {
    try {
      QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('projects')
              .doc(projectId)
              .collection('processes')
              .where('name', isEqualTo: 'To Do') // Chỉ lấy process "To Do"
              .limit(1)
              .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id; // Trả về id nếu có sẵn
      }

      return null; // Nếu không có thì trả về null (không tự tạo mới)
    } catch (e) {
      print("Lỗi khi lấy process: $e");
      return null;
    }
  }

  Future<void> saveTask() async {
    if (selectedProjectId == null ||
        selectedAssigneeId == null ||
        dueDate == null ||
        taskNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Vui lòng nhập đầy đủ thông tin!")),
      );
      return;
    }

    String taskId = FirebaseFirestore.instance.collection('tasks').doc().id;

    try {
      String? processId = await fetchHighestPriorityProcessIdBasedOnProject(
        selectedProjectId!,
      );

      if (processId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Không tìm thấy process phù hợp!")),
        );
        return;
      }

      // 🔍 Lấy tên người thực hiện từ Firestore
      DocumentSnapshot assigneeSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(selectedAssigneeId)
              .get();

      String assigneeName = assigneeSnapshot['fullName'] ?? 'Không rõ';

      await FirebaseFirestore.instance.collection('tasks').doc(taskId).set({
        'taskId': taskId,
        'name': taskNameController.text.trim(),
        'projectId': selectedProjectId,
        'processId': processId,
        'assigneeId': selectedAssigneeId,
        'assigneeName': assigneeName, // 👈 thêm dòng này
        'dueDate': Timestamp.fromDate(dueDate!),
        'createdAt': FieldValue.serverTimestamp(),
        'priority': 1,
        'status': 'To Do',
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Task đã được tạo thành công!")));

      setState(() {
        taskNameController.clear();
        selectedProjectId = null;
        selectedAssigneeId = null;
        dueDate = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Lỗi khi tạo Task: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tạo Task'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'), // Điều hướng về trang admin
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: selectedProjectId,
              onChanged: (value) async {
                setState(() => selectedProjectId = value);
                processId = await fetchHighestPriorityProcessIdBasedOnProject(
                  value!,
                );
                setState(() {}); // Cập nhật UI
              },
              items:
                  projects.map((project) {
                    return DropdownMenuItem(
                      value: project['id'],
                      child: Text(project['name'] ?? ""),
                    );
                  }).toList(),
              decoration: InputDecoration(labelText: "Chọn Project"),
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedAssigneeId,
              onChanged: (value) => setState(() => selectedAssigneeId = value),
              items:
                  assignees.map((user) {
                    return DropdownMenuItem(
                      value: user['id'],
                      child: Text(user['name'] ?? ""),
                    );
                  }).toList(),
              decoration: InputDecoration(labelText: "Chọn Người thực hiện"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: taskNameController,
              decoration: InputDecoration(labelText: 'Tên Task'),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() => dueDate = picked);
                }
              },
              child: Text(
                dueDate == null
                    ? "Chọn ngày"
                    : DateFormat('dd/MM/yyyy').format(dueDate!),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(onPressed: saveTask, child: Text("Lưu Task")),
            SizedBox(height: 20),
            if (selectedProjectId != null) ...[
              Text(
                "Danh sách Task trong 'To Do':",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream:
                      processId == null
                          ? null
                          : FirebaseFirestore.instance
                              .collection('tasks')
                              .where('projectId', isEqualTo: selectedProjectId)
                              .where('processId', isEqualTo: processId)
                              .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    var tasks = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        var task = tasks[index];
                        return ListTile(
                          title: Text(task['name']),
                          subtitle: Text(
                            "Ngày hết hạn: ${DateFormat('dd/MM/yyyy').format(task['dueDate'].toDate())}",
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
