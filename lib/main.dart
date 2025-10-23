import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'pages/login_page.dart';
import 'pages/map_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env
  await dotenv.load(fileName: '.env');
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  bool supabaseConfigured = false;
  if (supabaseUrl != null && supabaseAnonKey != null &&
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    supabaseConfigured = true;
  }

  runApp(MyApp(supabaseConfigured: supabaseConfigured));
}

class MyApp extends StatelessWidget {
  final bool supabaseConfigured;
  const MyApp({super.key, required this.supabaseConfigured});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = supabaseConfigured &&
        Supabase.instance.client.auth.currentUser != null;

    return MaterialApp(
      title: 'MyFavoriteMap',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      // Mostrar SIEMPRE LoginPage si no hay sesión (incluso si Supabase no está configurado)
      home: isLoggedIn
          ? MapPage(supabaseConfigured: true)
          : const LoginPage(),
    );
  }
}
