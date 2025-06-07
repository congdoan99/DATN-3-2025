import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:poro_2/AdminProjectScreen.dart';
import 'package:poro_2/ProjectDetailScreen.dart';
import 'package:poro_2/TaskDetailScreen.dart';
import 'package:poro_2/admin/admin_screen.dart';
import 'package:poro_2/create_task.dart';
import 'package:poro_2/profile_user_screen.dart';
import 'package:poro_2/user/CompletedProjectDetailScreen.dart';
import 'package:poro_2/user/CompletedProjectsScreen.dart';
import 'package:poro_2/user/NotificationScreen.dart';
import 'package:poro_2/user/SearchProjectScreen.dart';
import 'package:poro_2/user/StatisticsScreen.dart';
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
      // GoRoute(
      //   path: '/phone_sign_in',
      //   builder: (context, state) => const PhoneRegisterScreen(),
      // ),
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
      GoRoute(
        path: '/project-detail/:id/:name',
        builder: (context, state) {
          final projectId = state.pathParameters['id'];
          final projectName = state.pathParameters['name'];

          if (projectId == null || projectName == null) {
            return Scaffold(
              body: Center(child: Text("Lỗi: Không tìm thấy project")),
            );
          }
          return ProjectDetailScreen(
            projectId: projectId,
            projectName: projectName,
          );
        },
      ),

      GoRoute(
        path: '/task-detail/:taskId',
        builder: (context, state) {
          final taskId = state.pathParameters['taskId']!;
          return TaskDetailScreen(taskId: taskId);
        },
      ),

      GoRoute(
        path: '/notification',
        builder: (context, state) => NotificationScreen(),
      ),
      GoRoute(
        path: '/completed-projects',
        builder: (context, state) => CompletedProjectsScreen(),
      ),
      GoRoute(
        path: '/statistics',
        builder: (context, state) => StatisticsScreen(),
      ),
      GoRoute(
        path: '/search-project',
        builder: (context, state) => SearchProjectScreen(),
      ),
      GoRoute(
        path: '/completed-project-detail/:projectId',
        builder: (context, state) {
          final projectId = state.pathParameters['projectId']!;
          return CompletedProjectDetailScreen(projectId: projectId);
        },
      ),
    ],
    debugLogDiagnostics: true,
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
