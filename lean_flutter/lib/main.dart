import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/entry_provider.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database (only on mobile/desktop, not web)
  if (!kIsWeb) {
    await DatabaseService.instance.database;
  }

  // TODO: Initialize Supabase (Phase 2)
  // const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  // const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  // if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
  //   await SupabaseService.initialize(
  //     url: supabaseUrl,
  //     anonKey: supabaseAnonKey,
  //   );
  // }

  runApp(const LeanApp());
}

class LeanApp extends StatelessWidget {
  const LeanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EntryProvider()..initialize(),
      child: MaterialApp(
        title: 'Lean',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          // Minimal, clean theme
          brightness: Brightness.light,
          fontFamily: 'monospace',
          colorScheme: ColorScheme.light(
            primary: Colors.black,
            secondary: Colors.grey[800]!,
            surface: Colors.white,
            background: Colors.white,
          ),
          scaffoldBackgroundColor: Colors.white,
          textTheme: const TextTheme(
            bodyMedium: TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'monospace',
          colorScheme: ColorScheme.dark(
            primary: Colors.white,
            secondary: Colors.grey[300]!,
            surface: Colors.grey[900]!,
            background: Colors.black,
          ),
          scaffoldBackgroundColor: Colors.black,
          textTheme: const TextTheme(
            bodyMedium: TextStyle(
              fontSize: 16,
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
