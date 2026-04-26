import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/label.dart';

class LabelsScreen extends StatefulWidget {
  const LabelsScreen({super.key});

  @override
  State<LabelsScreen> createState() => _LabelsScreenState();
}

class _LabelsScreenState extends State<LabelsScreen> {
  final _db = DatabaseHelper.instance;
  List<Label> _labels = [];

  static const _palette = [
    '#F44336', '#E91E63', '#9C27B0', '#673AB7',
    '#3F51B5', '#2196F3', '#03A9F4', '#00BCD4',
    '#009688', '#4CAF50', '#8BC34A', '#CDDC39',
    '#FFC107', '#FF9800', '#FF5722', '#795548',
    '#607D8B', '#9E9E9E',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final labels = await _db.getAllLabels();
    setState(() => _labels = labels);
  }

  Future<void> _showLabelDialog({Label? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedColor = existing?.colorHex ?? _palette.first;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(existing == null ? 'Nueva etiqueta' : 'Editar etiqueta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 20),
                Text('Color', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _palette.map((hex) {
                    final color =
                        Color(int.parse(hex.replaceFirst('#', '0xFF')));
                    final isSelected = selectedColor == hex;
                    return GestureDetector(
                      onTap: () => setDlg(() => selectedColor = hex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withAlpha(150),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                try {
                  if (existing == null) {
                    await _db.insertLabel(
                        Label(name: name, colorHex: selectedColor));
                  } else {
                    await _db.updateLabel(
                        existing.copyWith(name: name, colorHex: selectedColor));
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  // UNIQUE constraint o cualquier error de BD
                  final isDuplicate = e.toString().contains('UNIQUE');
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isDuplicate
                              ? 'Ya existe una etiqueta con el nombre "$name"'
                              : 'Error al guardar la etiqueta',
                        ),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteLabel(Label label) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar etiqueta'),
        content: Text(
            '¿Eliminar "${label.name}"? Se eliminará de todas las cuentas y notas.'),
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
      await _db.deleteLabel(label.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final defaults = _labels.where((l) => l.isDefault).toList();
    final custom = _labels.where((l) => !l.isDefault).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Etiquetas',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _labels.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (defaults.isNotEmpty) ...[
                  _GroupHeader(title: 'Por defecto'),
                  ...defaults.map((l) => _LabelTile(
                        label: l,
                        onEdit: () => _showLabelDialog(existing: l),
                      )),
                  const SizedBox(height: 8),
                ],
                _GroupHeader(title: 'Personalizadas'),
                if (custom.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Sin etiquetas personalizadas',
                        style: TextStyle(color: scheme.outline)),
                  )
                else
                  ...custom.map((l) => _LabelTile(
                        label: l,
                        onEdit: () => _showLabelDialog(existing: l),
                        onDelete: () => _deleteLabel(l),
                      )),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLabelDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva etiqueta'),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  const _GroupHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              letterSpacing: 1.2),
        ),
      );
}

class _LabelTile extends StatelessWidget {
  final Label label;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const _LabelTile(
      {required this.label, required this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: label.color,
          radius: 14,
          child: const Icon(Icons.label, size: 14, color: Colors.white),
        ),
        title: Text(label.name,
            style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: onEdit),
            if (onDelete != null)
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20,
                    color: Theme.of(context).colorScheme.error),
                onPressed: onDelete,
              ),
          ],
        ),
      ),
    );
  }
}
