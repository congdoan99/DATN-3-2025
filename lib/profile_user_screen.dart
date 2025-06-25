import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:universal_html/html.dart' as html;

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

  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    if (widget.userData != null) {
      fullNameController.text = widget.userData!['fullName'] ?? '';
      phoneController.text = widget.userData!['phone'] ?? '';
      addressController.text = widget.userData!['address'] ?? '';
      _avatarUrl = widget.userData!['avatarUrl'];
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    User? user = _auth.currentUser;
    if (user == null) return;

    if (kIsWeb) {
      final html.FileUploadInputElement input = html.FileUploadInputElement();
      input.accept = 'image/*';
      input.click();

      input.onChange.listen((event) async {
        final file = input.files!.first;
        final reader = html.FileReader();

        reader.readAsArrayBuffer(file);
        reader.onLoadEnd.listen((event) async {
          final Uint8List data = reader.result as Uint8List;
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
          final ref = FirebaseStorage.instance.ref(
            'avatars/${user.uid}/$fileName',
          );

          try {
            final uploadTask = await ref.putData(data);
            final downloadUrl = await uploadTask.ref.getDownloadURL();

            // Cập nhật Firestore, tạo trường avatarUrl nếu chưa có
            await _firestore.collection('users').doc(user.uid).set({
              'avatarUrl': downloadUrl,
            }, SetOptions(merge: true));

            setState(() {
              _avatarUrl = downloadUrl;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ảnh đại diện đã được cập nhật')),
            );
          } catch (e) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Lỗi khi cập nhật ảnh: $e')));
          }
        });
      });
    } else {
      // TODO: Mobile support
    }
  }

  void _saveUserInfo() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'fullName': fullNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'address': addressController.text.trim(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thông tin đã được cập nhật')),
      );
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatar =
        _avatarUrl != null
            ? NetworkImage(
              "$_avatarUrl?ts=${DateTime.now().millisecondsSinceEpoch}",
            )
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Thông tin cá nhân"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/user_screen'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFBBDEFB),
                      backgroundImage: avatar,
                      child:
                          avatar == null
                              ? const Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.blue,
                              )
                              : null,
                    ),
                    InkWell(
                      onTap: _pickAndUploadAvatar,
                      borderRadius: BorderRadius.circular(20),
                      child: const CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.edit, size: 16, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  fullNameController.text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  label: "Tên đầy đủ",
                  controller: fullNameController,
                  icon: Icons.person,
                ),
                _buildTextField(
                  label: "Số điện thoại",
                  controller: phoneController,
                  icon: Icons.phone,
                ),
                _buildTextField(
                  label: "Địa chỉ",
                  controller: addressController,
                  icon: Icons.location_on,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text("Cập nhật"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saveUserInfo,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
