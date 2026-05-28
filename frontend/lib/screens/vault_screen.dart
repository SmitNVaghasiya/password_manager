import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/vault_session.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final _searchController = TextEditingController();
  List<PasswordEntry> _entries = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = _query.isEmpty
        ? await DatabaseService.instance.getAllEntries()
        : await DatabaseService.instance.searchEntries(_query);
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  void _onSearch(String q) {
    _query = q;
    VaultSession.instance.resetAutoLockTimer();
    _load();
  }

  String _initial(String siteName) {
    if (siteName.isEmpty) return '?';
    return siteName[0].toUpperCase();
  }

  Color _avatarColor(String siteName) {
    final colors = [
      const Color(0xFF1E5F4E),
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFFB45309),
      const Color(0xFF0F766E),
    ];
    return colors[siteName.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PassMgr'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/settings').then((_) => _load()),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: const InputDecoration(
                hintText: 'Search passwords...',
                prefixIcon: Icon(Icons.search, color: AppColors.inkMute, size: 20),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
                : _entries.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          VaultSession.instance.resetAutoLockTimer();
          Navigator.of(context).pushNamed('/edit').then((_) => _load());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmpty() {
    if (_query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: AppColors.inkMute),
            const SizedBox(height: 12),
            Text(
              'No results for "$_query"',
              style: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.emeraldSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.lock_outline, size: 36, color: AppColors.emerald),
            ),
            const SizedBox(height: 20),
            const Text(
              'No passwords yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap + to add your first password.',
              style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    return Scrollbar(
      thumbVisibility: true,
      child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      cacheExtent: 500,
      itemCount: _entries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final entry = _entries[i];
        return _EntryCard(
          entry: entry,
          initial: _initial(entry.siteName),
          avatarColor: _avatarColor(entry.siteName),
          onTap: () {
            FocusScope.of(context).unfocus();
            VaultSession.instance.resetAutoLockTimer();
            Navigator.of(context)
                .pushNamed('/detail', arguments: entry.id)
                .then((_) => _load());
          },
        );
      },
    ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final PasswordEntry entry;
  final String initial;
  final Color avatarColor;
  final VoidCallback onTap;

  const _EntryCard({
    required this.entry,
    required this.initial,
    required this.avatarColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: avatarColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: avatarColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.siteName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.username,
                      style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.inkMute, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
