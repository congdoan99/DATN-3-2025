import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_ui_auth/firebase_ui_auth.dart' as uiAuth;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<auth.User?>(
      // Theo dõi sự thay đổi trạng thái xác thực
      stream: auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return _buildSignInScreen(); // Hiển thị màn hình đăng nhập nếu chưa đăng nhập
        }

        return FutureBuilder<String>(
          // Lấy vai trò của người dùng từ Firestore
          future: _getUserRole(snapshot.data!),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final role = roleSnapshot.data;

            // Sau khi có vai trò, điều hướng tới màn hình tương ứng
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (role == 'admin') {
                context.go('/admin'); // Điều hướng đến Admin screen
              } else if (role == 'manager' || role == 'employee') {
                context.go('/user_screen'); // Điều hướng đến User screen
              } else {
                auth.FirebaseAuth.instance
                    .signOut(); // Đăng xuất nếu không có vai trò hợp lệ
                context.go('/auth_gate'); // Quay lại màn hình đăng nhập
              }
            });

            return const Scaffold(); // Không cần UI gì nếu chỉ muốn điều hướng
          },
        );
      },
    );
  }

  Future<String> _getUserRole(auth.User user) async {
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
    return userDoc.exists
        ? (userDoc['role'] ?? 'user')
        : 'user'; // Trả về vai trò của người dùng
  }

  Widget _buildSignInScreen() {
    return uiAuth.SignInScreen(
      providers: [uiAuth.EmailAuthProvider()],
      actions: [],
      showAuthActionSwitch: false,
      headerMaxExtent: 200,
      headerBuilder: (context, constraints, _) {
        return Padding(
          padding: const EdgeInsets.only(top: 40, bottom: 20),
          child: Image.asset(
            'assets/logo_cd.png',
            height: 100,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              print("Error loading image: $error");
              return const Text('Không load được ảnh');
            },
          ),
        );
      },
      subtitleBuilder:
          (context, action) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Quản lý công việc hiệu quả',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
      footerBuilder: (context, action) {
        return Column(
          children: [
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                context.push('/phone_sign_in');
              },
              child: const Text(
                'Bạn chưa có tài khoản? Đăng ký',
                style: TextStyle(
                  color: Colors.blue, // Đăng ký màu xanh dương
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
