import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/entry_provider.dart';
import 'services/database_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

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
        theme: AppTheme.darkTheme(), // Use exact PWA theme
        darkTheme: AppTheme.darkTheme(),
        themeMode: ThemeMode.dark, // Always dark for now
        home: const HomeScreen(),
      ),
    );
  }
}
