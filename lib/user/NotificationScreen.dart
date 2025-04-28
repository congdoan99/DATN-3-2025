import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
  }

  // Stream để lấy tất cả thông báo (bỏ điều kiện isRead)
  Stream<QuerySnapshot> getNotificationsStream() {
    return _firestore
        .collection('notifications')
        .where('assignee', isEqualTo: _user?.uid)
        .orderBy('timestamp', descending: true) // Sắp xếp mới nhất lên đầu
        .snapshots();
  }

  // Đánh dấu thông báo là đã đọc
  void _markAsRead(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Thông Báo"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed:
              () => context.go('/user_screen'), // Điều hướng về trang admin
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: getNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("Không có thông báo nào."));
          }

          var notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notificationData =
                  notifications[index].data() as Map<String, dynamic>;
              String notificationId = notifications[index].id;
              String title =
                  notificationData['title'] ?? 'Thông báo không có tiêu đề';
              String description =
                  notificationData['description'] ?? 'Không có mô tả';
              Timestamp timestamp = notificationData['timestamp'];
              DateTime notificationTime = timestamp.toDate();
              String timeAgo = _getTimeAgo(notificationTime);

              return Card(
                color:
                    notificationData['isRead']
                        ? Colors.white
                        : Colors
                            .blue[100], // Chưa đọc thì nền xanh, đã đọc thì nền trắng
                child: ListTile(
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(description),
                      SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  onTap: () {
                    if (!notificationData['isRead']) {
                      _markAsRead(notificationId); // Chỉ đánh dấu nếu chưa đọc
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đã đọc thông báo')),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays} ngày trước';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} giờ trước';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} phút trước';
    } else {
      return 'Vừa xong';
    }
  }
}
