import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:todo_app_flutterv2/features/dashboard/dashboard_screen.dart';
import 'package:todo_app_flutterv2/features/notes/note_editor_screen.dart';
import 'package:todo_app_flutterv2/features/task_list/task_list_screen.dart';
import 'package:todo_app_flutterv2/features/trash/trash_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/list/:listId',
        builder: (context, state) =>
            TaskListScreen(listId: state.pathParameters['listId']!),
      ),
      GoRoute(
        path: '/note/:noteId',
        builder: (context, state) =>
            NoteEditorScreen(noteId: state.pathParameters['noteId']!),
      ),
      GoRoute(
        path: '/trash',
        builder: (context, state) => const TrashScreen(),
      ),
    ],
  );
});
