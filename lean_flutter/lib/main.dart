import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/entry_provider.dart';
import 'services/database_service.dart';
import 'services/supabase_service.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local database (only on mobile/desktop, not web)
  if (!kIsWeb) {
    await DatabaseService.instance.database;
  }

  // Initialize Supabase
  SupabaseService? supabaseService;
  if (SupabaseConfig.isConfigured) {
    try {
      await SupabaseService.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      supabaseService = SupabaseService.instance;
      debugPrint('✓ Supabase initialized');
    } catch (e) {
      debugPrint('⚠ Supabase init failed: $e');
      // Continue without Supabase (offline-first architecture)
    }
  }

  runApp(LeanApp(supabaseService: supabaseService));
}

class LeanApp extends StatelessWidget {
  final SupabaseService? supabaseService;

  const LeanApp({super.key, this.supabaseService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(supabaseService)),
        ChangeNotifierProxyProvider<AuthProvider, EntryProvider>(
          create: (_) {
            final provider = EntryProvider();
            // Initialize immediately with Supabase reference (even if not authenticated yet)
            final supabase = supabaseService;
            if (supabase != null) {
              provider.setSupabase(supabase);
            }
            return provider;
          },
          update: (_, authProvider, entryProvider) {
            // Re-initialize when authentication state changes
            if (authProvider.isAuthenticated && supabaseService != null) {
              print('🔄 Auth state changed, re-initializing EntryProvider...');
              entryProvider!.initialize(supabase: supabaseService);
            }
            return entryProvider!;
          },
        ),
      ],
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, _) {
          // Get the current theme colors
          final colors = themeProvider.colors;

          // Build a MaterialApp with the dynamic theme
          return MaterialApp(
            title: 'Lean',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: colors.background.computeLuminance() > 0.5
                  ? Brightness.light
                  : Brightness.dark,
              scaffoldBackgroundColor: colors.background,
              cardColor: colors.entryBackground,
              primaryColor: colors.accent,
              fontFamily: themeProvider.currentTheme == 'paper'
                  ? 'serif' // Paper theme uses serif font
                  : 'monospace', // All others use monospace
            ),
            home: const HomeScreen(), // Always show HomeScreen (offline-first)
          );
        },
      ),
    );
  }
}
