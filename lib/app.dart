import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poro_2/AdminProjectScreen.dart';
import 'package:poro_2/admin/admin_screen.dart';
import 'package:poro_2/create_task.dart';
import 'package:poro_2/user_screen.dart';

import 'auth_gate.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final GoRouter _router = GoRouter(
    initialLocation: '/auth_gate',
    routes: [
      GoRoute(path: '/auth_gate', builder: (context, state) => AuthGate()),
      GoRoute(path: '/admin', builder: (context, state) => AdminScreen()),
      GoRoute(path: '/user_screen', builder: (context, state) => UserScreen()),
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
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Admin Panel',
      theme: ThemeData(primarySwatch: Colors.blue),
      routerConfig: _router, // Sử dụng `go_router`
    );
  }
}
