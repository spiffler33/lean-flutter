import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/entry_provider.dart';
import '../services/command_handler.dart';
import '../theme/theme_colors.dart';

/// Floating Action Button for mobile - Redesigned for frictionless UX
///
/// Primary actions (one tap):
/// - Search
/// - Today
/// - Themes (visual picker)
/// - More (reveals secondary menu)
///
/// Secondary actions (via More):
/// - Export, Stats, Yesterday, Week, Clear, Templates
class MobileFAB extends StatefulWidget {
  final Function(String)? onTemplateInsert;

  const MobileFAB({super.key, this.onTemplateInsert});

  @override
  State<MobileFAB> createState() => _MobileFABState();
}

class _MobileFABState extends State<MobileFAB>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  bool _showMoreMenu = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isExpanded = !_isExpanded;
      _showMoreMenu = false; // Reset more menu
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _closeMenu() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
        _showMoreMenu = false;
        _animationController.reverse();
      });
    }
  }

  void _toggleMoreMenu() {
    setState(() {
      _showMoreMenu = !_showMoreMenu;
    });
  }

  Future<void> _handleAction(String action) async {
    _closeMenu();

    final provider = context.read<EntryProvider>();
    final commandHandler = CommandHandler(provider, context);

    // Execute commands
    await commandHandler.handleCommand(action);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final colors = themeProvider.colors;

        return Stack(
          alignment: Alignment.bottomRight,
          children: [
            // Backdrop (dismiss menu when tapped)
            if (_isExpanded)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _closeMenu,
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                  ),
                ),
              ),

            // Menu items
            if (_isExpanded)
              Positioned(
                bottom: 80,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // PRIMARY MENU (always visible when expanded)

                    // Search
                    _buildMenuItem(
                      icon: Icons.search,
                      label: 'Search',
                      colors: colors,
                      onTap: () async {
                        _closeMenu();
                        final searchTerm = await showDialog<String>(
                          context: context,
                          builder: (context) => _SearchDialog(colors: colors),
                        );
                        if (searchTerm != null && searchTerm.isNotEmpty) {
                          await _handleAction('/search $searchTerm');
                        }
                      },
                    ),
                    const SizedBox(height: 10),

                    // Today
                    _buildMenuItem(
                      icon: Icons.today,
                      label: 'Today',
                      colors: colors,
                      onTap: () => _handleAction('/today'),
                    ),
                    const SizedBox(height: 10),

                    // Events (AI Intelligence)
                    _buildMenuItem(
                      icon: Icons.event_note,
                      label: 'Events',
                      colors: colors,
                      onTap: () => _handleAction('/events'),
                    ),
                    const SizedBox(height: 10),

                    // Patterns (AI Intelligence)
                    _buildMenuItem(
                      icon: Icons.insights,
                      label: 'Patterns',
                      colors: colors,
                      onTap: () => _handleAction('/patterns'),
                    ),
                    const SizedBox(height: 10),

                    // Themes (visual picker)
                    _buildMenuItem(
                      icon: Icons.palette,
                      label: 'Themes',
                      colors: colors,
                      onTap: () {
                        _closeMenu();
                        _showThemePicker(context, colors);
                      },
                    ),
                    const SizedBox(height: 10),

                    // More (toggle secondary menu)
                    _buildMenuItem(
                      icon: _showMoreMenu ? Icons.expand_less : Icons.expand_more,
                      label: 'More',
                      colors: colors,
                      onTap: _toggleMoreMenu,
                    ),

                    // SECONDARY MENU (shown when More is tapped)
                    if (_showMoreMenu) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: 200,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.entryBackground,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCompactMenuItem('Context', Icons.psychology, colors, () => _handleAction('/context')),
                            _buildCompactMenuItem('Export', Icons.download, colors, () => _handleAction('/export')),
                            _buildCompactMenuItem('Stats', Icons.bar_chart, colors, () => _handleAction('/stats')),
                            _buildCompactMenuItem('Yesterday', Icons.history, colors, () => _handleAction('/yesterday')),
                            _buildCompactMenuItem('Week', Icons.calendar_today, colors, () => _handleAction('/week')),
                            _buildCompactMenuItem('Clear View', Icons.clear_all, colors, () => _handleAction('/clear')),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Main FAB
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: _toggleMenu,
                backgroundColor: colors.accent,
                elevation: 6,
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  turns: _isExpanded ? 0.125 : 0,
                  child: Icon(
                    _isExpanded ? Icons.close : Icons.menu,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build a primary menu item (icon + label on side)
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required dynamic colors,
    required VoidCallback onTap,
  }) {
    return FadeTransition(
      opacity: _expandAnimation,
      child: ScaleTransition(
        scale: _expandAnimation,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.entryBackground,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Icon button
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(28),
              color: colors.inputBackground,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    color: colors.accent,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a compact menu item (for secondary menu)
  Widget _buildCompactMenuItem(String label, IconData icon, dynamic colors, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: colors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show visual theme picker (no typing required!)
  void _showThemePicker(BuildContext context, dynamic colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.modalBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true, // Allow custom height
      builder: (context) => Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Theme',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Scrollable theme options
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildThemeOption(context, themeProvider, 'minimal', 'Clean minimal', Colors.grey.shade800, const Color(0xFF4CAF50)),
                          _buildThemeOption(context, themeProvider, 'matrix', 'Green terminal', Colors.black, const Color(0xFF00FF41)),
                          _buildThemeOption(context, themeProvider, 'paper', 'Warm paper', const Color(0xFFF5F1E8), const Color(0xFFD4A574)),
                          _buildThemeOption(context, themeProvider, 'midnight', 'Deep blues', const Color(0xFF0A0E27), const Color(0xFF6366F1)),
                          _buildThemeOption(context, themeProvider, 'mono', 'Pure B&W', Colors.white, Colors.black),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, ThemeProvider themeProvider, String themeName, String description, Color bg, Color accent) {
    final isActive = themeProvider.currentTheme == themeName;

    return InkWell(
      onTap: () async {
        await themeProvider.applyTheme(themeName);
        if (context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    themeName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: bg.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: (bg.computeLuminance() > 0.5 ? Colors.black : Colors.white).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle, color: accent, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Search dialog for mobile
class _SearchDialog extends StatefulWidget {
  final dynamic colors;

  const _SearchDialog({required this.colors});

  @override
  State<_SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<_SearchDialog> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.colors.modalBackground,
      title: Text(
        'Search',
        style: TextStyle(color: widget.colors.textPrimary),
      ),
      content: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: widget.colors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Enter search term...',
          hintStyle: TextStyle(color: widget.colors.textSecondary),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: widget.colors.inputBorder),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: widget.colors.accent),
          ),
        ),
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            Navigator.of(context).pop(value.trim());
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: widget.colors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () {
            final term = _searchController.text.trim();
            if (term.isNotEmpty) {
              Navigator.of(context).pop(term);
            }
          },
          child: Text(
            'Search',
            style: TextStyle(color: widget.colors.accent),
          ),
        ),
      ],
    );
  }
}
