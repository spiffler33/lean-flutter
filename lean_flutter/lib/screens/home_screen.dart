import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/entry_provider.dart';
import '../widgets/entry_widget.dart';

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

      // Clear input
      _inputController.clear();

      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Saved'),
            duration: Duration(milliseconds: 800),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lean', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          // Entry count
          Consumer<EntryProvider>(
            builder: (context, provider, _) {
              return FutureBuilder<int>(
                future: provider.getEntryCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        '$count',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Input box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _inputController,
              focusNode: _inputFocus,
              maxLines: 3,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'Type your thought... (Enter to save)',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _saveEntry(),
            ),
          ),

          // Entry list
          Expanded(
            child: Consumer<EntryProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
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
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _saveEntry,
        tooltip: 'Save',
        child: const Icon(Icons.save),
      ),
    );
  }
}
