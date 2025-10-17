import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/entry_provider.dart';
import '../widgets/entry_widget.dart';
import '../theme/app_theme.dart';

/// Main screen: Input box + Entry list
/// Philosophy: Frictionless. Type, save, search.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _inputController = TextEditingController();
  final _inputFocus = FocusNode();
  bool _showSaveFlash = false;

  @override
  void initState() {
    super.initState();
    // Always focus input on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    final content = _inputController.text.trim();
    if (content.isEmpty) return;

    final provider = context.read<EntryProvider>();

    try {
      await provider.createEntry(content);

      // Clear input FIRST to prevent newline
      _inputController.clear();

      // Show subtle green flash (like original)
      if (mounted) {
        setState(() => _showSaveFlash = true);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showSaveFlash = false);
        });
      }
    } catch (e) {
      if (mounted) {
        // Only show error as SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Header: "L E A N" with line (matching original)
                  Column(
                    children: [
                      Text(
                        'L  E  A  N',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 8,
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '━━━━━━━━━',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Input box with save flash animation
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkEntryBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _showSaveFlash ? AppTheme.accentGreen : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _showSaveFlash
                              ? AppTheme.accentGreen.withOpacity(0.15)
                              : Colors.black.withOpacity(0.08),
                          blurRadius: _showSaveFlash ? 8 : 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
              child: KeyboardListener(
                focusNode: FocusNode(),
                onKeyEvent: (KeyEvent event) {
                  if (event is KeyDownEvent) {
                    // Check for Enter key without Shift
                    if (event.logicalKey == LogicalKeyboardKey.enter &&
                        !HardwareKeyboard.instance.isShiftPressed) {
                      _saveEntry();
                    }
                  }
                },
                child: TextField(
                  controller: _inputController,
                  focusNode: _inputFocus,
                  maxLines: 1, // Single line
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.darkTextPrimary,
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'What\'s on your mind?',
                    hintStyle: TextStyle(
                      color: AppTheme.darkTextSecondary,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  // Don't use onSubmitted - it interferes
                ),
              ),
            ),

                  const SizedBox(height: 24),

                  // Entry list
                  Expanded(
                    child: Consumer<EntryProvider>(
                      builder: (context, provider, _) {
                        if (provider.isLoading) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppTheme.accentGreen,
                            ),
                          );
                        }

                        if (provider.error != null) {
                          return Center(
                            child: Text(
                              'Error: ${provider.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                          );
                        }

                        if (provider.entries.isEmpty) {
                          return const Center(
                            child: Text(
                              'No entries yet.\nStart typing above!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.darkTextSecondary,
                                fontSize: 14,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: provider.entries.length,
                          itemBuilder: (context, index) {
                            final entry = provider.entries[index];
                            return EntryWidget(entry: entry);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
