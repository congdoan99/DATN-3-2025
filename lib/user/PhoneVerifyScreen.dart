import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PhoneVerifyScreen extends StatefulWidget {
  final String email;
  final String password;

  const PhoneVerifyScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<PhoneVerifyScreen> createState() => _PhoneVerifyScreenState();
}

class _PhoneVerifyScreenState extends State<PhoneVerifyScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String? _verificationId;
  bool _codeSent = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    if (widget.email.isEmpty || widget.password.isEmpty) {
      // Quay về màn đăng ký nếu thiếu email hoặc password
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/auth_gate');
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nhập số điện thoại')));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    await auth.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (auth.PhoneAuthCredential credential) async {
        // Android tự động verify OTP thành công
        await _signUpWithCredential(credential, phone);
      },
      verificationFailed: (e) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      },
      codeSent: (verificationId, resendToken) {
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _loading = false;
        });
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyCode() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || _verificationId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nhập mã OTP')));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final credential = auth.PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );

    await _signUpWithCredential(credential, _phoneController.text.trim());
  }

  Future<void> _signUpWithCredential(
    auth.PhoneAuthCredential phoneCredential,
    String phone,
  ) async {
    try {
      // Tạo user email/password trước
      final userCredential = await auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: widget.email,
            password: widget.password,
          );

      // Link số điện thoại vào tài khoản
      await userCredential.user!.linkWithCredential(phoneCredential);

      // Lưu thông tin user vào Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'email': widget.email,
            'phoneNumber': phone,
            'role': 'employee',
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Điều hướng sau khi đăng ký thành công
      if (mounted) {
        context.go('/user_screen');
      }
    } on auth.FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Xác thực số điện thoại')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Số điện thoại'),
              keyboardType: TextInputType.phone,
              enabled: !_codeSent,
            ),
            if (_codeSent)
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(labelText: 'Mã OTP'),
                keyboardType: TextInputType.number,
              ),
            const SizedBox(height: 20),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (!_codeSent)
              ElevatedButton(
                onPressed: _loading ? null : _sendCode,
                child:
                    _loading
                        ? const CircularProgressIndicator()
                        : const Text('Gửi mã OTP'),
              ),
            if (_codeSent)
              ElevatedButton(
                onPressed: _loading ? null : _verifyCode,
                child:
                    _loading
                        ? const CircularProgressIndicator()
                        : const Text('Xác nhận OTP'),
              ),
          ],
        ),
      ),
    );
  }
}
