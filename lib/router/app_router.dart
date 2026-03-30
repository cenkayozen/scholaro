import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/role_selection_screen.dart';
import '../screens/teacher/teacher_auth_screen.dart';
import '../screens/teacher/teacher_home_screen.dart';
import '../screens/teacher/student_list_screen.dart';
import '../screens/teacher/homework_screen.dart';
import '../screens/teacher/participation_screen.dart';
import '../screens/teacher/quiz_screen.dart';
import '../screens/teacher/portfolio_screen.dart';
import '../screens/teacher/random_selector_screen.dart';
import '../screens/teacher/export_screen.dart';
import '../screens/teacher/class_detail_screen.dart';
import '../screens/student/student_login_screen.dart';
import '../screens/student/student_home_screen.dart';
import '../screens/student/student_homework_view.dart';
import '../screens/student/student_participation_view.dart';
import '../screens/student/student_quiz_view.dart';
import '../screens/student/student_portfolio_view.dart';
import '../screens/monitor/monitor_login_screen.dart';
import '../screens/monitor/monitor_home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const RoleSelectionScreen(),
      ),

      // ── Teacher Routes ────────────────────────────────────────────────────
      GoRoute(
        path: '/teacher/login',
        builder: (_, __) => const TeacherLoginScreen(),
      ),
      GoRoute(
        path: '/teacher/register',
        builder: (_, __) => const TeacherRegisterScreen(),
      ),
      GoRoute(
        path: '/teacher/home',
        builder: (_, __) => const TeacherHomeScreen(),
      ),

      // Class-scoped routes
      GoRoute(
        path: '/teacher/class/:teacherId/:classId/detail',
        builder: (_, state) => ClassDetailScreen(
          teacherId: state.pathParameters['teacherId']!,
          classId: state.pathParameters['classId']!,
          className: state.extra as String? ?? 'Class',
        ),
      ),
      GoRoute(
        path: '/teacher/class/:teacherId/:classId/students',
        builder: (_, state) => StudentListScreen(
          teacherId: state.pathParameters['teacherId']!,
          classId: state.pathParameters['classId']!,
          className: state.extra as String? ?? 'Class',
        ),
      ),
      GoRoute(
        path: '/teacher/class/:teacherId/:classId/homework',
        builder: (_, state) => HomeworkScreen(
          teacherId: state.pathParameters['teacherId']!,
          classId: state.pathParameters['classId']!,
          className: state.extra as String? ?? 'Class',
        ),
      ),
      GoRoute(
        path: '/teacher/class/:teacherId/:classId/participation',
        builder: (_, state) => ParticipationScreen(
          teacherId: state.pathParameters['teacherId']!,
          classId: state.pathParameters['classId']!,
          className: state.extra as String? ?? 'Class',
        ),
      ),
      GoRoute(
        path: '/teacher/class/:teacherId/:classId/quizzes',
        builder: (_, state) => QuizScreen(
          teacherId: state.pathParameters['teacherId']!,
          classId: state.pathParameters['classId']!,
          className: state.extra as String? ?? 'Class',
        ),
      ),
      GoRoute(
        path: '/teacher/class/:teacherId/:classId/portfolio',
        builder: (_, state) => PortfolioScreen(
          teacherId: state.pathParameters['teacherId']!,
          classId: state.pathParameters['classId']!,
          className: state.extra as String? ?? 'Class',
        ),
      ),
      GoRoute(
        path: '/teacher/class/:teacherId/:classId/random',
        builder: (_, state) => RandomSelectorScreen(
          teacherId: state.pathParameters['teacherId']!,
          classId: state.pathParameters['classId']!,
          className: state.extra as String? ?? 'Class',
        ),
      ),
      GoRoute(
        path: '/teacher/class/:teacherId/:classId/export',
        builder: (_, state) => ExportScreen(
          teacherId: state.pathParameters['teacherId']!,
          classId: state.pathParameters['classId']!,
          className: state.extra as String? ?? 'Class',
        ),
      ),

      // ── Homework Monitor Routes ───────────────────────────────────────────
      GoRoute(
        path: '/monitor/login',
        builder: (_, __) => const MonitorLoginScreen(),
      ),
      GoRoute(
        path: '/monitor/home',
        builder: (_, __) => const MonitorHomeScreen(),
      ),

      // ── Student Routes ────────────────────────────────────────────────────
      GoRoute(
        path: '/student/login',
        builder: (_, __) => const StudentLoginScreen(),
      ),
      GoRoute(
        path: '/student/home',
        builder: (_, __) => const StudentHomeScreen(),
      ),
      GoRoute(
        path: '/student/homework/:teacherId/:classId/:studentId',
        builder: (_, state) => StudentHomeworkView(
          teacherId: state.pathParameters['teacherId']!,
          classId: state.pathParameters['classId']!,
          studentId: state.pathParameters['studentId']!,
        ),
      ),
      GoRoute(
        path: '/student/participation/:teacherId/:classId/:studentId',
        builder: (_, state) => StudentParticipationView(
          teacherId: state.pathParameters['teacherId']!,
          classId: state.pathParameters['classId']!,
          studentId: state.pathParameters['studentId']!,
        ),
      ),
      GoRoute(
        path: '/student/quizzes/:teacherId/:classId/:studentId',
        builder: (_, state) => StudentQuizView(
          teacherId: state.pathParameters['teacherId']!,
          classId: state.pathParameters['classId']!,
          studentId: state.pathParameters['studentId']!,
        ),
      ),
      GoRoute(
        path: '/student/portfolio/:teacherId/:classId/:studentId',
        builder: (_, state) => StudentPortfolioView(
          teacherId: state.pathParameters['teacherId']!,
          classId: state.pathParameters['classId']!,
          studentId: state.pathParameters['studentId']!,
        ),
      ),
    ],
  );
});
