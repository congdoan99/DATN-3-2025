import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  String role = 'user';

  Future<void> createUser() async {
    const String apiKey = "AIzaSyA5qhrjwQiTMZgaQR_SDrVrUEffYtZ6L1Q";
    const String url =
        "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": emailController.text.trim(),
          "password": passwordController.text.trim(),
          "returnSecureToken": false,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        String userId = data["localId"];

        await _firestore.collection('users').doc(userId).set({
          'email': emailController.text.trim(),
          'fullName': fullNameController.text.trim(),
          'phone': phoneController.text.trim(),
          'address': addressController.text.trim(),
          'role': role,
          'isVisible': true,
        });

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('User created successfully')));

          emailController.clear();
          passwordController.clear();
          phoneController.clear();
          fullNameController.clear();
          addressController.clear();

          setState(() {
            role = 'user';
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User creation failed: ${data["error"]["message"]}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> toggleUserStatus(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'isVisible': false,
    });
  }

  void _editUser(DocumentSnapshot userDoc) {
    TextEditingController nameController = TextEditingController(
      text: userDoc['fullName'],
    );
    TextEditingController phoneController = TextEditingController(
      text: userDoc['phone'],
    );
    TextEditingController addressController = TextEditingController(
      text: userDoc['address'],
    );
    String selectedRole = userDoc['role'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Chỉnh sửa người dùng"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Tên đầy đủ'),
              ),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(labelText: 'Số điện thoại'),
              ),
              TextField(
                controller: addressController,
                decoration: InputDecoration(labelText: 'Địa chỉ'),
              ),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: InputDecoration(labelText: 'Vai trò'),
                onChanged: (value) => selectedRole = value!,
                items:
                    ['admin', 'manager', 'employee', 'user']
                        .map(
                          (role) =>
                              DropdownMenuItem(value: role, child: Text(role)),
                        )
                        .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () async {
                await _firestore.collection('users').doc(userDoc.id).update({
                  'fullName': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                  'address': addressController.text.trim(),
                  'role': selectedRole,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("Cập nhật thành công!")));
              },
              child: Text("Lưu"),
            ),
          ],
        );
      },
    );
  }

  void confirmLogout() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Confirm Logout'),
            content: Text('Are you sure you want to log out?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await _auth.signOut();
                    if (mounted) {
                      context.go('/auth_gate');
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logout failed: $e')),
                    );
                  }
                },
                child: Text('Logout'),
              ),
            ],
          ),
    );
  }

  // Hàm hiển thị form đăng ký
  void _showRegistrationForm() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Tạo tài khoản mới"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(labelText: 'Mật khẩu'),
                  obscureText: true,
                ),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(labelText: 'Số điện thoại'),
                ),
                TextField(
                  controller: fullNameController,
                  decoration: InputDecoration(labelText: 'Tên đầy đủ'),
                ),
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(labelText: 'Địa chỉ'),
                ),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: InputDecoration(labelText: 'Vai trò'),
                  onChanged: (value) => setState(() => role = value!),
                  items:
                      ['admin', 'manager', 'employee', 'user']
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () async {
                await createUser();
                Navigator.pop(context);
              },
              child: Text("Lưu"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Panel'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline),
            onPressed: () {
              context.go('/create_project');
            },
            tooltip: 'Tạo Project',
          ),
          IconButton(
            icon: Icon(Icons.add_task),
            onPressed: () {
              context.go('/create_task');
            },
            tooltip: 'Tạo Task',
          ),
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: confirmLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Nút "Tạo tài khoản" thay vì form luôn hiển thị
          ElevatedButton(
            onPressed: _showRegistrationForm,
            child: Text('Tạo tài khoản'),
          ),
          Expanded(
            child: StreamBuilder(
              stream:
                  _firestore
                      .collection('users')
                      .where('isVisible', isEqualTo: true)
                      .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                return ListView(
                  padding: EdgeInsets.symmetric(
                    vertical: 8.0,
                    horizontal: 10.0,
                  ), // Thêm khoảng cách
                  children:
                      snapshot.data!.docs.map((doc) {
                        return Card(
                          elevation: 4, // Thêm độ đổ bóng nhẹ
                          margin: EdgeInsets.symmetric(
                            vertical: 8,
                          ), // Khoảng cách giữa các card
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              10,
                            ), // Bo tròn góc nhẹ
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 12,
                            ), // Padding vừa phải
                            leading: CircleAvatar(
                              radius: 25, // Hình avatar nhỏ hơn
                              backgroundColor: Colors.blueAccent,
                              child: Text(
                                doc['fullName'][0], // Lấy chữ cái đầu tiên của tên người dùng
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              doc['fullName'],
                              style: TextStyle(
                                fontSize:
                                    16, // Kích thước chữ nhỏ hơn để vừa vặn
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 5.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email: ${doc['email']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    'Role: ${doc['role']}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: Colors.orange),
                                  onPressed: () => _editUser(doc),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => toggleUserStatus(doc.id),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
