import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/entry_provider.dart';
import '../services/command_handler.dart';

/// Floating Action Button for mobile
/// Shows speed dial menu with quick commands:
/// - Search
/// - Export
/// - Stats
/// - Theme
class MobileFAB extends StatefulWidget {
  const MobileFAB({super.key});

  @override
  State<MobileFAB> createState() => _MobileFABState();
}

class _MobileFABState extends State<MobileFAB>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
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
        _animationController.reverse();
      });
    }
  }

  Future<void> _handleCommand(String command) async {
    _closeMenu();

    final provider = context.read<EntryProvider>();
    final commandHandler = CommandHandler(provider, context);

    // Execute command
    await commandHandler.handleCommand(command);
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

            // Speed dial menu items
            if (_isExpanded)
              Positioned(
                bottom: 80,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Search
                    _buildSpeedDialItem(
                      icon: Icons.search,
                      label: 'Search',
                      colors: colors,
                      delay: 0,
                      onTap: () async {
                        _closeMenu();
                        // Show search input dialog
                        final searchTerm = await showDialog<String>(
                          context: context,
                          builder: (context) => _SearchDialog(colors: colors),
                        );
                        if (searchTerm != null && searchTerm.isNotEmpty) {
                          await _handleCommand('/search $searchTerm');
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    // Export
                    _buildSpeedDialItem(
                      icon: Icons.download,
                      label: 'Export',
                      colors: colors,
                      delay: 50,
                      onTap: () => _handleCommand('/export'),
                    ),
                    const SizedBox(height: 12),
                    // Stats
                    _buildSpeedDialItem(
                      icon: Icons.bar_chart,
                      label: 'Stats',
                      colors: colors,
                      delay: 100,
                      onTap: () => _handleCommand('/stats'),
                    ),
                    const SizedBox(height: 12),
                    // Help
                    _buildSpeedDialItem(
                      icon: Icons.help_outline,
                      label: 'Help',
                      colors: colors,
                      delay: 150,
                      onTap: () => _handleCommand('/help'),
                    ),
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
                  turns: _isExpanded ? 0.125 : 0, // 45 degree rotation when open
                  child: Icon(
                    _isExpanded ? Icons.close : Icons.more_horiz,
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

  Widget _buildSpeedDialItem({
    required IconData icon,
    required String label,
    required dynamic colors,
    required int delay,
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
