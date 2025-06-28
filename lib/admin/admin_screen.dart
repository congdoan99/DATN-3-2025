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
          ).showSnackBar(SnackBar(content: Text('Tạo người dùng thành công')));

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
            content: Text(
              'Tạo người dùng thất bại: ${data["error"]["message"]}',
            ),
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
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa người dùng này không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _firestore.collection('users').doc(userId).update({
                    'isVisible': false,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Người dùng đã bị xóa')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi khi xóa người dùng: $e')),
                  );
                }
              },
              child: Text('Xóa'),
            ),
          ],
        );
      },
    );
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

  void confirmLogout(BuildContext context, FirebaseAuth auth) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Đăng xuất'),
            content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.of(context, rootNavigator: true).pop(),
                child: const Text('Hủy'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context, rootNavigator: true).pop();
                  try {
                    await auth.signOut();
                    if (context.mounted) {
                      context.go('/auth_gate');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Đăng xuất thất bại: $e')),
                      );
                    }
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red, // 👈 Màu chữ đỏ
                ),
                child: const Text('Đăng xuất'),
              ),
            ],
          ),
    );
  }

  void _showRegistrationForm() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            "Tạo tài khoản mới",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  controller: emailController,
                  label: 'Email',
                  icon: Icons.email,
                ),
                _buildTextField(
                  controller: passwordController,
                  label: 'Mật khẩu',
                  icon: Icons.lock,
                  isPassword: true,
                ),
                _buildTextField(
                  controller: phoneController,
                  label: 'Số điện thoại',
                  icon: Icons.phone,
                ),
                _buildTextField(
                  controller: fullNameController,
                  label: 'Tên đầy đủ',
                  icon: Icons.person,
                ),
                _buildTextField(
                  controller: addressController,
                  label: 'Địa chỉ',
                  icon: Icons.home,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: InputDecoration(
                    labelText: 'Vai trò',
                    prefixIcon: Icon(Icons.security),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onChanged: (value) => setState(() => role = value!),
                  items:
                      ['admin', 'manager', 'employee', 'user']
                          .map(
                            (r) => DropdownMenuItem(
                              value: r,
                              child: Text(r.toUpperCase()),
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
            ElevatedButton.icon(
              icon: Icon(Icons.save),
              label: Text("Lưu"),
              onPressed: () async {
                await createUser();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quản lý Hệ Thống'),
        actions: [
          IconButton(
            icon: Icon(Icons.list_alt),
            onPressed: () => context.go('/project_list'),
            tooltip: 'Danh sách dự án',
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline),
            onPressed: () => context.go('/create_project'),
            tooltip: 'Tạo dự án',
          ),
          IconButton(
            icon: Icon(Icons.add_task),
            onPressed: () => context.go('/create_task'),
            tooltip: 'Tạo công việc',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Đăng xuất',
            onPressed: () => confirmLogout(context, FirebaseAuth.instance),
          ),
        ],
      ),
      body: Column(
        children: [
          // KHỐI THÊM NGƯỜI DÙNG
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent),
              ),
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Thêm người dùng mới",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: Icon(Icons.person_add),
                    label: Text("Tạo tài khoản"),
                    onPressed: _showRegistrationForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // KHỐI DANH SÁCH NGƯỜI DÙNG
          Expanded(
            child: StreamBuilder(
              stream:
                  _firestore
                      .collection('users')
                      .where('isVisible', isEqualTo: true)
                      .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width,
                    ),
                    child: DataTable(
                      columnSpacing: 20,
                      headingRowColor: MaterialStateProperty.all(
                        Colors.blue.shade100,
                      ),
                      columns: const [
                        DataColumn(label: Text('Họ và tên')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('SĐT')),
                        DataColumn(label: Text('Vai trò')),
                        DataColumn(label: Text('Hành động')),
                      ],
                      rows:
                          docs.map((doc) {
                            final fullName = doc['fullName'] ?? '';
                            final email = doc['email'] ?? '';
                            final phone = doc['phone'] ?? '';
                            final role = doc['role'] ?? '';

                            return DataRow(
                              cells: [
                                DataCell(Text(fullName)),
                                DataCell(Text(email)),
                                DataCell(Text(phone)),
                                DataCell(Text(role)),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.edit,
                                          color: Colors.amber[800],
                                        ),
                                        tooltip: 'Chỉnh sửa',
                                        onPressed: () => _editUser(doc),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.delete,
                                          color: Colors.redAccent,
                                        ),
                                        tooltip: 'Xóa',
                                        onPressed:
                                            () => toggleUserStatus(doc.id),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
