import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PhoneSignInScreen extends StatelessWidget {
  const PhoneSignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PhoneInputScreen(
      actions: [
        AuthStateChangeAction<SignedIn>((context, state) async {
          final user = state.user;

          // Kiểm tra nếu là user mới
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .get();

          if (!userDoc.exists) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(user?.uid)
                .set({
                  'uid': user?.uid,
                  'phone': user?.phoneNumber,
                  'role': 'employee', // Gán quyền mặc định là nhân viên
                  'createdAt': FieldValue.serverTimestamp(),
                });
          }

          context.go('/user_screen'); // Điều hướng sang User screen
        }),
      ],
    );
  }
}
