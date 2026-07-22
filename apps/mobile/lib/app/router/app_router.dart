import 'package:go_router/go_router.dart';

import '../navigation/main_shell.dart';


final appRouter = GoRouter(
  initialLocation: '/',

  routes: [

    GoRoute(
      path: '/',
      builder: (context, state) {
        return const MainShell();
      },
    ),

  ],
);