import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class WarningScreen extends StatelessWidget {
  const WarningScreen({super.key});

  Stream<QuerySnapshot> getUserTasks(String userId) {
    return FirebaseFirestore.instance
        .collection('tasks')
        .where('assigneeId', isEqualTo: userId)
        .snapshots();
  }

  bool isOverdue(Timestamp dueDate) {
    return dueDate.toDate().isBefore(DateTime.now());
  }

  bool isAlmostDue(Timestamp dueDate) {
    final diff = dueDate.toDate().difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 2;
  }

  String formatDate(Timestamp timestamp) {
    return DateFormat('dd/MM/yyyy').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Cảnh báo")),
        body: Center(child: Text("Bạn chưa đăng nhập.")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Cảnh báo công việc")),
      body: StreamBuilder<QuerySnapshot>(
        stream: getUserTasks(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final tasks = snapshot.data?.docs ?? [];

          final almostDue =
              tasks.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final due = data['dueDate'] as Timestamp?;
                final status = data['status'] ?? '';
                return due != null && status != 'Complete' && isAlmostDue(due);
              }).toList();

          final overdue =
              tasks.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final due = data['dueDate'] as Timestamp?;
                final status = data['status'] ?? '';
                return due != null && status != 'Complete' && isOverdue(due);
              }).toList();

          Widget buildTaskCard(
            Map<String, dynamic> data,
            String taskId,
            bool overdue,
          ) {
            return Card(
              elevation: 2,
              color: overdue ? Colors.red[50] : Colors.orange[50],
              margin: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: ListTile(
                leading: Icon(
                  overdue ? Icons.error_outline : Icons.warning_amber,
                  color: overdue ? Colors.red : Colors.orange,
                ),
                title: Text(
                  data['name'] ?? 'Không có tên',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data['projectName'] != null)
                      Text("Dự án: ${data['projectName']}"),
                    if (data['createdByName'] != null)
                      Text("Người giao: ${data['createdByName']}"),
                    if (data['assigneeName'] != null)
                      Text("Người nhận: ${data['assigneeName']}"),
                    if (data['dueDate'] != null)
                      Text(
                        "Hạn: ${formatDate(data['dueDate'])}",
                        style: TextStyle(
                          color: overdue ? Colors.red : Colors.orange[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                onTap: () {
                  context.go('/task-detail/$taskId');
                },
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🟠 Sắp hết hạn
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "🟠 Sắp hết hạn",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.orange),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              almostDue.isEmpty
                                  ? Center(
                                    child: Text(
                                      "Chưa có công việc sắp hết hạn.",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                  : ListView.builder(
                                    itemCount: almostDue.length,
                                    itemBuilder: (context, index) {
                                      final data =
                                          almostDue[index].data()
                                              as Map<String, dynamic>;
                                      return buildTaskCard(
                                        data,
                                        almostDue[index].id,
                                        false,
                                      );
                                    },
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // 🔴 Đã trễ hạn
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "🔴 Đã trễ hạn",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child:
                              overdue.isEmpty
                                  ? Center(
                                    child: Text(
                                      "Chưa có công việc trễ hạn.",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                  : ListView.builder(
                                    itemCount: overdue.length,
                                    itemBuilder: (context, index) {
                                      final data =
                                          overdue[index].data()
                                              as Map<String, dynamic>;
                                      return buildTaskCard(
                                        data,
                                        overdue[index].id,
                                        true,
                                      );
                                    },
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
