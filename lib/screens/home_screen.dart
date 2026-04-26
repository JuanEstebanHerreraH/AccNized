import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/label.dart';
import '../widgets/account_card.dart';
import 'account_form_screen.dart';
import 'account_detail_screen.dart';
import 'labels_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Account> _accounts = [];
  List<Label> _labels = [];
  // Multi-select: conjunto de IDs seleccionados
  final Set<int> _selectedLabelIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [silent] = true → no muestra spinner, evita el flash negro
  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final labelFilter =
        _selectedLabelIds.isEmpty ? null : _selectedLabelIds.toList();
    final accounts = await _db.getAllAccounts(labelIds: labelFilter);
    final labels = await _db.getAllLabels();
    setState(() {
      _accounts = accounts;
      _labels = labels;
      _loading = false;
    });
  }

  Future<void> _deleteAccount(Account account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: Text('¿Eliminar "${account.identifier}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteAccount(account.id!);
      _load();
    }
  }

  void _toggleLabel(int id) {
    setState(() {
      if (_selectedLabelIds.contains(id)) {
        _selectedLabelIds.remove(id);
      } else {
        _selectedLabelIds.add(id);
      }
    });
    _load(silent: true); // recarga sin flash negro
  }

  void _clearFilter() {
    setState(() => _selectedLabelIds.clear());
    _load(silent: true);
  }

  List<Label> get _activeLabels =>
      _labels.where((l) => _selectedLabelIds.contains(l.id)).toList();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasFilter = _selectedLabelIds.isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: scheme.surface,
      // ── Drawer hamburguesa ─────────────────────────────────────
      drawer: _LabelDrawer(
        labels: _labels,
        selectedIds: _selectedLabelIds,
        onToggle: _toggleLabel,
        onClearAll: _clearFilter,
        onManageLabels: () async {
          _scaffoldKey.currentState?.closeDrawer();
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const LabelsScreen()));
          _load();
        },
      ),
      appBar: AppBar(
        leading: IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.menu),
              if (hasFilter)
                Positioned(
                  top: -3,
                  right: -3,
                  child: Container(
                    width: 10,
                    height: 10,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: scheme.surface, width: 1.5),
                    ),
                    child: Text(
                      '${_selectedLabelIds.length}',
                      style: TextStyle(
                          fontSize: 6,
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          tooltip: 'Filtrar por etiqueta',
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', width: 28, height: 28),
            const SizedBox(width: 10),
            const Text('AccNized',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        // Chips de filtros activos bajo el título
        bottom: !hasFilter
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(
                    _activeLabels.length > 3 ? 64 : 36),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 12, right: 12, bottom: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      ..._activeLabels.map((l) => _ActiveChip(
                            label: l,
                            onRemove: () => _toggleLabel(l.id!),
                          )),
                      if (_activeLabels.length > 1)
                        _ClearAllChip(onTap: _clearFilter),
                    ],
                  ),
                ),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? _EmptyState(
                  filtered: hasFilter,
                  onClear: _clearFilter,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: _accounts.length,
                  itemBuilder: (ctx, i) {
                    final account = _accounts[i];
                    return AccountCard(
                      account: account,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AccountDetailScreen(
                                accountId: account.id!),
                          ),
                        );
                        _load();
                      },
                      onEdit: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AccountFormScreen(account: account),
                          ),
                        );
                        _load();
                      },
                      onDelete: () => _deleteAccount(account),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AccountFormScreen()));
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva cuenta'),
      ),
    );
  }
}

// ── Drawer lateral con checkboxes ───────────────────────────────
class _LabelDrawer extends StatelessWidget {
  final List<Label> labels;
  final Set<int> selectedIds;
  final ValueChanged<int> onToggle;
  final VoidCallback onClearAll;
  final VoidCallback onManageLabels;

  const _LabelDrawer({
    required this.labels,
    required this.selectedIds,
    required this.onToggle,
    required this.onClearAll,
    required this.onManageLabels,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasFilter = selectedIds.isNotEmpty;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtrar por etiqueta',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (hasFilter)
                    TextButton(
                      onPressed: onClearAll,
                      child: const Text('Limpiar'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Opción "Todas"
            ListTile(
              leading: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: !hasFilter
                      ? scheme.primary
                      : scheme.primary.withAlpha(60),
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(
                'Todas las cuentas',
                style: TextStyle(
                  fontWeight: !hasFilter
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: !hasFilter ? scheme.primary : scheme.onSurface,
                ),
              ),
              trailing: !hasFilter
                  ? Icon(Icons.check, color: scheme.primary, size: 18)
                  : null,
              selected: !hasFilter,
              selectedTileColor: scheme.primary.withAlpha(20),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              onTap: onClearAll,
            ),
            if (labels.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  'Etiquetas',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: scheme.outline),
                ),
              ),
              ...labels.map((l) {
                final sel = selectedIds.contains(l.id);
                return ListTile(
                  leading: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: sel ? l.color : l.color.withAlpha(70),
                      shape: BoxShape.circle,
                      border: sel
                          ? Border.all(color: l.color, width: 2)
                          : Border.all(
                              color: l.color.withAlpha(120),
                              width: 1.5),
                    ),
                  ),
                  title: Text(
                    l.name,
                    style: TextStyle(
                      fontWeight:
                          sel ? FontWeight.w600 : FontWeight.normal,
                      color: sel ? l.color : scheme.onSurface,
                    ),
                  ),
                  trailing: Checkbox(
                    value: sel,
                    activeColor: l.color,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    onChanged: (_) => onToggle(l.id!),
                  ),
                  selected: sel,
                  selectedTileColor: l.color.withAlpha(18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.only(
                      left: 20, right: 8, top: 2, bottom: 2),
                  onTap: () => onToggle(l.id!),
                );
              }),
            ],
            const Spacer(),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.label_outline),
              title: const Text('Gestionar etiquetas'),
              onTap: onManageLabels,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chips activos en AppBar ──────────────────────────────────────
class _ActiveChip extends StatelessWidget {
  final Label label;
  final VoidCallback onRemove;

  const _ActiveChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 6, 3),
      decoration: BoxDecoration(
        color: label.color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: label.color.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration:
                BoxDecoration(color: label.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label.name,
            style: TextStyle(
              fontSize: 12,
              color: label.color.withAlpha(220),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 3),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close,
                size: 13, color: label.color.withAlpha(180)),
          ),
        ],
      ),
    );
  }
}

class _ClearAllChip extends StatelessWidget {
  final VoidCallback onTap;
  const _ClearAllChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.errorContainer.withAlpha(80),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.error.withAlpha(80)),
        ),
        child: Text(
          'Limpiar todo',
          style: TextStyle(
            fontSize: 12,
            color: scheme.error,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool filtered;
  final VoidCallback onClear;
  const _EmptyState({required this.filtered, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtered
                ? Icons.filter_list_off
                : Icons.manage_accounts_outlined,
            size: 72,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            filtered
                ? 'Sin cuentas con estas etiquetas'
                : 'No hay cuentas aún',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(context).colorScheme.outline),
          ),
          if (filtered) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: onClear, child: const Text('Ver todas')),
          ],
        ],
      ),
    );
  }
}
