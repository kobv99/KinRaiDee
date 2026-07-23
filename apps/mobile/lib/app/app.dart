import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'router/app_router.dart';

class KinRaiDeeApp extends StatelessWidget {
  const KinRaiDeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KinRaiDee',

      debugShowCheckedModeBanner: false,

      theme: AppTheme.light,

      routerConfig: appRouter,
    );
  }
}
