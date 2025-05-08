import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Danh sách thông báo')),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('notifications')
                .where(
                  'assignee',
                  isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                )
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('Không có thông báo.'));
          }

          print("Dữ liệu thông báo: ${snapshot.data!.docs}");

          var notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var doc = notifications[index];
              print("Thông báo: ${doc['title']}");

              bool isRead = doc['isRead'] ?? false;
              return Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                elevation: 3,
                child: ListTile(
                  title: Text(
                    doc['title'] ?? 'Không có tiêu đề',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(doc['description'] ?? 'Không có mô tả'),
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('notifications')
                          .doc(doc.id)
                          .delete();
                    },
                  ),
                  leading: Icon(
                    isRead ? Icons.check_circle : Icons.circle,
                    color: isRead ? Colors.green : Colors.grey,
                  ),
                  onTap: () async {
                    await FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(doc.id)
                        .update({'isRead': true});
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
