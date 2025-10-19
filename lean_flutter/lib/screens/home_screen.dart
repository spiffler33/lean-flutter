import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/entry_provider.dart';
import '../services/command_handler.dart';
import '../widgets/entry_widget.dart';
import '../widgets/mobile_fab.dart';
import '../providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth_screen.dart';
import '../utils/time_divider.dart' as time_divider_util;
import '../utils/platform_utils.dart';

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

      // Haptic feedback on save (iOS light impact)
      await PlatformUtils.lightImpact();

      // Show subtle green flash (like original)
      if (mounted) {
        setState(() => _showSaveFlash = true);
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _showSaveFlash = false);
        });
      }
    } catch (e) {
      if (mounted) {
        // Enhanced error toast with better mobile UX
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Save Failed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Check storage space',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _saveEntry(),
            ),
          ),
        );
      }
    }
  }

  /// Handle auth button click
  void _handleAuthClick(AuthProvider authProvider) {
    if (authProvider.isAuthenticated) {
      // Show sign out confirmation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Sign Out'),
          content: Text('Signed in as ${authProvider.user?.email}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                authProvider.signOut();
                Navigator.pop(context);
              },
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );
    } else {
      // Show auth screen as modal
      showDialog(
        context: context,
        builder: (context) => const Dialog(
          child: SizedBox(
            width: 400,
            child: AuthScreen(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final colors = themeProvider.colors;

        // Responsive layout: Detect screen size
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;
        final horizontalPadding = isMobile ? 16.0 : 20.0;

        return Scaffold(
          backgroundColor: colors.background,
          // FAB for mobile only (< 600px width)
          floatingActionButton: isMobile ? const MobileFAB() : null,
          body: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 680),
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 20,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Header: "L E A N" with line (matching original)
                  // Use Stack to ensure LEAN text and decorative line are truly centered
                  Column(
                    children: [
                      SizedBox(
                        height: 48, // Match touch target height
                        child: Stack(
                          children: [
                            // Centered "L E A N" text
                            Center(
                              child: Text(
                                'L  E  A  N',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 8,
                                  color: colors.logoColor.withOpacity(0.4),
                                ),
                              ),
                            ),
                            // Auth indicator (positioned left)
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: Consumer<AuthProvider>(
                                builder: (context, authProvider, _) {
                                  return InkWell(
                                    onTap: () => _handleAuthClick(authProvider),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      child: Text(
                                        authProvider.isAuthenticated ? '●' : '○',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: authProvider.isAuthenticated
                                              ? colors.accent
                                              : colors.textSecondary.withOpacity(0.5),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Todo counter (positioned right)
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              child: Consumer<EntryProvider>(
                                builder: (context, provider, _) {
                                  final todoCount = provider.openTodoCount;

                                  if (todoCount == 0) {
                                    return const SizedBox.shrink();
                                  }

                                  final isFiltered = provider.filterLabel == 'open todos';

                                  return InkWell(
                                    onTap: () {
                                      PlatformUtils.selectionClick();
                                      provider.toggleTodoFilter();
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 12,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isFiltered
                                              ? colors.accent.withOpacity(0.15)
                                              : colors.inputBackground.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '□ $todoCount',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isFiltered
                                                ? colors.accent
                                                : colors.textSecondary,
                                            fontWeight: isFiltered ? FontWeight.w500 : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),
                      // Decorative line - also centered
                      Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: Text(
                          '━━━━━━━━━',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: colors.timeDivider.withOpacity(0.2),
                          ),
                          textAlign: TextAlign.center,
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

                  // Entry list with keyboard dismiss on scroll
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
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Error icon
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(40),
                                  ),
                                  child: const Icon(
                                    Icons.error_outline,
                                    size: 40,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Error title
                                const Text(
                                  'Something went wrong',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Error message
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(
                                    provider.error!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Retry button
                                ElevatedButton.icon(
                                  onPressed: () => provider.loadEntries(),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Retry'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: colors.accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Wrap ListView in NotificationListener to dismiss keyboard on scroll
                        return NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            // Dismiss keyboard when user starts scrolling
                            if (notification is ScrollStartNotification) {
                              FocusScope.of(context).unfocus();
                            }
                            return false;
                          },
                          child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: provider.entries.length + (provider.showTimeDivider ? 1 : 0),
                          itemBuilder: (context, index) {
                            // Show time divider at the top if enabled
                            if (index == 0 && provider.showTimeDivider) {
                              // Mobile-friendly: no decorative hyphens, shorter format
                              final dividerText = isMobile
                                  ? time_divider_util.TimeDivider.formatDividerText(DateTime.now())
                                  : time_divider_util.TimeDivider.createDividerElement(DateTime.now());

                              return Container(
                                width: double.infinity,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Text(
                                  dividerText,
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 11,
                                    letterSpacing: isMobile ? 0.5 : 1,
                                    color: colors.timeDivider.withOpacity(0.4),
                                    fontFamily: 'monospace',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            }

                            // If no entries, show enhanced empty state
                            if (provider.entries.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 40),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Empty state icon
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          color: colors.inputBackground,
                                          borderRadius: BorderRadius.circular(40),
                                        ),
                                        child: Icon(
                                          Icons.edit_outlined,
                                          size: 36,
                                          color: colors.textSecondary.withOpacity(0.5),
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      // Welcome message
                                      Text(
                                        provider.filterLabel != null
                                            ? 'No entries found'
                                            : 'Welcome to Lean!',
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      // Instructions
                                      Text(
                                        provider.filterLabel != null
                                            ? 'Try /clear to see all entries'
                                            : 'Type anything above\nand press Enter',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                      if (provider.filterLabel == null) ...[
                                        const SizedBox(height: 20),
                                        // Helpful tip
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.inputBackground.withOpacity(0.5),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'Try /help for commands',
                                            style: TextStyle(
                                              color: colors.accent,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }

                            // Adjust index if we showed divider
                            final entryIndex = provider.showTimeDivider ? index - 1 : index;
                            final entry = provider.entries[entryIndex];

                            // Swipe-to-delete wrapper (mobile UX)
                            return Dismissible(
                              key: Key(entry.id?.toString() ?? 'entry-$entryIndex'),
                              direction: DismissDirection.endToStart, // Swipe left only
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(colors.borderRadius),
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                // Show confirmation dialog
                                return await showDialog<bool>(
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
                              },
                              onDismissed: (direction) async {
                                // Heavy haptic feedback on delete
                                await PlatformUtils.heavyImpact();

                                if (entry.id != null) {
                                  await provider.deleteEntry(entry.id!);
                                }
                              },
                              child: EntryWidget(
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
                                  // Show confirmation dialog (for desktop/web hover actions)
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
                              ),
                            );
                          },
                          ),
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