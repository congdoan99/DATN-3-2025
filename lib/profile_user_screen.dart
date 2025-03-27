import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileUserScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const ProfileUserScreen({super.key, this.userData});

  @override
  _ProfileUserScreenState createState() => _ProfileUserScreenState();
}

class _ProfileUserScreenState extends State<ProfileUserScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.userData != null) {
      fullNameController.text = widget.userData!['fullName'] ?? '';
      phoneController.text = widget.userData!['phone'] ?? '';
      addressController.text = widget.userData!['address'] ?? '';
    }
  }

  void _saveUserInfo() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'fullName': fullNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
      });

      setState(() {
        isEditing = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Thông tin đã được cập nhật')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Thông tin cá nhân")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(Icons.account_circle, size: 80, color: Colors.blue),
            ),
            SizedBox(height: 20),
            TextField(
              controller: fullNameController,
              decoration: InputDecoration(labelText: "Tên"),
              style: TextStyle(color: Colors.black, fontSize: 16),
              enabled: isEditing,
            ),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(labelText: "Số điện thoại"),
              style: TextStyle(color: Colors.black, fontSize: 16),
              enabled: isEditing,
            ),
            TextField(
              controller: addressController,
              decoration: InputDecoration(labelText: "Địa chỉ"),
              style: TextStyle(color: Colors.black, fontSize: 16),
              enabled: isEditing,
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isEditing = !isEditing;
                    });
                  },
                  child: Text(isEditing ? "Hủy" : "Chỉnh sửa"),
                ),
                ElevatedButton(
                  onPressed: isEditing ? _saveUserInfo : null,
                  child: Text("Lưu"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
