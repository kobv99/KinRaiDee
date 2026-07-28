import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

class KinRaiDeeApp extends StatefulWidget {
  const KinRaiDeeApp({super.key, this.theme});

  final ThemeData? theme;

  @override
  State<KinRaiDeeApp> createState() => _KinRaiDeeAppState();
}

class _KinRaiDeeAppState extends State<KinRaiDeeApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter();
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KinRaiDee',
      debugShowCheckedModeBanner: false,
      theme: widget.theme ?? AppTheme.light,
      routerConfig: _router,
    );
  }
}
