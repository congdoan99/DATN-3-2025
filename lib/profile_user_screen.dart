import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool enabled = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade200,
        ),
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Thông tin cá nhân"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
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
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue.shade100,
                        child: Icon(Icons.person, size: 50, color: Colors.blue),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        fullNameController.text,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                _buildTextField(
                  label: "Tên đầy đủ",
                  controller: fullNameController,
                  icon: Icons.person,
                  enabled: isEditing,
                ),
                _buildTextField(
                  label: "Số điện thoại",
                  controller: phoneController,
                  icon: Icons.phone,
                  enabled: isEditing,
                ),
                _buildTextField(
                  label: "Địa chỉ",
                  controller: addressController,
                  icon: Icons.location_on,
                  enabled: isEditing,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(isEditing ? Icons.cancel : Icons.edit),
                        onPressed: () {
                          setState(() {
                            isEditing = !isEditing;
                          });
                        },
                        label: Text(isEditing ? "Hủy" : "Chỉnh sửa"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isEditing ? Colors.grey : Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.save),
                        onPressed: isEditing ? _saveUserInfo : null,
                        label: Text("Lưu"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
