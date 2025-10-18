import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/entry_provider.dart';
import '../services/command_handler.dart';
import '../widgets/entry_widget.dart';
import '../providers/theme_provider.dart';
import '../utils/time_divider.dart' as time_divider_util;

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

    // Handle keyboard events
    _inputFocus.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
          _saveEntry();
          // Re-focus immediately after save
          Future.microtask(() {
            if (mounted) {
              _inputFocus.requestFocus();
            }
          });
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    };
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

    // Check if it's a command
    if (content.startsWith('/')) {
      final commandHandler = CommandHandler(provider, context);

      // Special handling for template commands
      if (content == '/essay') {
        setState(() {
          _inputController.text = CommandHandler.essayTemplate;
          _showSaveFlash = true;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showSaveFlash = false);
        });
        return;
      }

      if (content == '/idea') {
        setState(() {
          _inputController.text = CommandHandler.ideaTemplate;
          _showSaveFlash = true;
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showSaveFlash = false);
        });
        return;
      }

      // Handle other commands
      final wasCommand = await commandHandler.handleCommand(content);
      if (wasCommand) {
        // Clear input after command
        _inputController.clear();
        return;
      }
    }

    // Not a command, save as entry
    try {
      await provider.createEntry(content);

      // Clear input
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
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final colors = themeProvider.colors;

        return Scaffold(
          backgroundColor: colors.background,
          body: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 680),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Header: "L E A N" with line (matching original)
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Spacer(),
                          Text(
                            'L  E  A  N',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 8,
                              color: colors.logoColor.withOpacity(0.4),
                            ),
                          ),
                          const Spacer(),
                          // Todo counter (clickable)
                          Consumer<EntryProvider>(
                            builder: (context, provider, _) {
                              final todoCount = provider.entries
                                  .where((e) => e.isTodo && !e.isDone)
                                  .length;

                              if (todoCount == 0) {
                                return const SizedBox.shrink();
                              }

                              final isFiltered = provider.filterLabel == 'open todos';

                              return GestureDetector(
                                onTap: () => provider.toggleTodoFilter(),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isFiltered
                                        ? colors.accent.withOpacity(0.2)
                                        : colors.inputBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isFiltered
                                          ? colors.accent
                                          : colors.accent.withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '□ $todoCount',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isFiltered
                                          ? colors.accent
                                          : colors.textPrimary.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '━━━━━━━━━',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: colors.timeDivider.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Filter indicator (shows when filter is active)
                  Consumer<EntryProvider>(
                    builder: (context, provider, _) {
                      if (provider.filterLabel == null) {
                        return const SizedBox.shrink();
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Showing: ${provider.filterLabel}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary.withOpacity(0.5),
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => provider.clearFilter(),
                              child: Text(
                                'Clear (Esc)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Input box with save flash animation (OUTER container)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(16), // Outer padding
                    decoration: BoxDecoration(
                      color: colors.inputContainer,
                      borderRadius: BorderRadius.circular(
                        themeProvider.currentTheme == 'mono' ? 0 : 12,
                      ),
                      boxShadow: themeProvider.currentTheme == 'mono'
                          ? [] // No shadow for mono theme
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.inputBackground,
                        borderRadius: BorderRadius.circular(colors.borderRadius),
                        border: Border.all(
                          color: _showSaveFlash
                              ? colors.accent
                              : colors.inputBorder,
                          width: colors.borderWidth,
                        ),
                      ),
                      padding: const EdgeInsets.all(12), // EXACT match: 12px all sides from CSS
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocus,
                        maxLines: null, // Auto-expand for multi-line
                        minLines: 1, // Start with 1 line
                        keyboardType: TextInputType.multiline,
                        autofocus: true,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(
                          fontSize: 16,
                          color: colors.textPrimary,
                          height: 1.5, // Match CSS line-height
                        ),
                        decoration: InputDecoration(
                          hintText: 'What\'s on your mind?',
                          hintStyle: TextStyle(
                            color: colors.textSecondary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Entry list
                  Expanded(
                    child: Consumer<EntryProvider>(
                      builder: (context, provider, _) {
                        if (provider.isLoading) {
                          return Center(
                            child: CircularProgressIndicator(
                              color: colors.accent,
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

                        // Show ListView even when empty (to display time divider)
                        return ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: provider.entries.length + (provider.showTimeDivider ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show time divider at the top if enabled
                            if (index == 0 && provider.showTimeDivider) {
                              final dividerText = time_divider_util.TimeDivider.createDividerElement(DateTime.now());
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Text(
                                  dividerText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1,
                                    color: colors.timeDivider.withOpacity(0.4),
                                    fontFamily: 'monospace',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            // If no entries, show empty state message after divider
                            if (provider.entries.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Center(
                                  child: Text(
                                    'No entries yet.\nStart typing above!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // Adjust index if we showed divider
                            final entryIndex = provider.showTimeDivider ? index - 1 : index;
                            final entry = provider.entries[entryIndex];

                            return EntryWidget(
                                  entry: entry,
                                  onToggleTodo: entry.isTodo
                                      ? () => provider.toggleTodo(entry)
                                      : null,
                                  onEdit: (updatedEntry) async {
                                    await provider.updateEntry(updatedEntry);
                                    // Reload entries to refresh the list
                                    await provider.loadEntries();
                                  },
                                  onDelete: (entryToDelete) async {
                                    // Show confirmation dialog
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: colors.modalBackground,
                                        title: Text(
                                          'Delete Entry?',
                                          style: TextStyle(color: colors.textPrimary),
                                        ),
                                        content: Text(
                                          'This action cannot be undone.',
                                          style: TextStyle(color: colors.textSecondary),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: Text(
                                              'Cancel',
                                              style: TextStyle(color: colors.textSecondary),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: const Text(
                                              'Delete',
                                              style: TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true && entryToDelete.id != null) {
                                      await provider.deleteEntry(entryToDelete.id!);
                                    }
                                  },
                                );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}