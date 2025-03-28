import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poro_2/AdminProjectScreen.dart';
import 'package:poro_2/admin/admin_screen.dart';
import 'package:poro_2/create_task.dart';
import 'package:poro_2/profile_user_screen.dart';
import 'package:poro_2/user_screen.dart';

import 'auth_gate.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GoRouter router = GoRouter(
    initialLocation: '/auth_gate',
    routes: [
      GoRoute(path: '/auth_gate', builder: (context, state) => AuthGate()),
      GoRoute(path: '/user_screen', builder: (context, state) => UserScreen()),
      GoRoute(path: '/admin', builder: (context, state) => AdminScreen()),
      GoRoute(
        path: '/create_project',
        builder: (context, state) => AdminProjectScreen(),
      ),
      GoRoute(
        path: '/create_task',
        builder: (context, state) {
          return CreateTaskScreen();
        },
      ),
      GoRoute(
        path: '/profile_user',
        builder: (context, state) {
          final userData = state.extra as Map<String, dynamic>?;
          return ProfileUserScreen(userData: userData);
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Admin Panel',
      theme: ThemeData(primarySwatch: Colors.blue),
      routerConfig: router, // Sử dụng `go_router`
    );
  }
}
