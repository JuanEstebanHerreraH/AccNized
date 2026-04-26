import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/label.dart';
import '../models/note.dart';
import '../widgets/label_chip.dart';
import 'note_editor_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final _db = DatabaseHelper.instance;
  List<Note> _notes = [];
  List<Label> _labels = [];
  int? _selectedLabelId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final notes = await _db.getAllPublicNotes(labelId: _selectedLabelId);
    final labels = await _db.getAllLabels();
    setState(() {
      _notes = notes;
      _labels = labels;
      _loading = false;
    });
  }

  Future<void> _openNote({Note? existing}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: existing)),
    );
    _load();
  }

  Future<void> _deleteNote(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar nota'),
        content: Text('¿Eliminar "${note.title}"?'),
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
      await _db.deleteNote(note.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Notas',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: _labels.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: _LabelFilterBar(
                  labels: _labels,
                  selectedId: _selectedLabelId,
                  onSelected: (id) {
                    setState(() => _selectedLabelId = id);
                    _load();
                  },
                ),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.note_alt_outlined,
                          size: 72, color: scheme.outlineVariant),
                      const SizedBox(height: 16),
                      Text(
                        _selectedLabelId != null
                            ? 'Sin notas con esta etiqueta'
                            : 'Sin notas aún',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: scheme.outline),
                      ),
                      if (_selectedLabelId != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _selectedLabelId = null);
                            _load();
                          },
                          child: const Text('Ver todas'),
                        ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: _notes.length,
                    itemBuilder: (ctx, i) {
                      final note = _notes[i];
                      return _NoteCard(
                        note: note,
                        onTap: () => _openNote(existing: note),
                        onDelete: () => _deleteNote(note),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNote(),
        icon: const Icon(Icons.edit_note),
        label: const Text('Nueva nota'),
      ),
    );
  }
}

class _LabelFilterBar extends StatelessWidget {
  final List<Label> labels;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  const _LabelFilterBar({
    required this.labels,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _Chip(
              label: 'Todas',
              selected: selectedId == null,
              onTap: () => onSelected(null)),
          const SizedBox(width: 8),
          ...labels.map((l) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Chip(
                  label: l.name,
                  selected: selectedId == l.id,
                  color: l.color,
                  onTap: () =>
                      onSelected(selectedId == l.id ? null : l.id),
                ),
              )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;
  const _Chip(
      {required this.label,
      required this.selected,
      this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected
        ? (color ?? scheme.primary)
        : scheme.surfaceContainerHighest;
    final fg = selected ? Colors.white : scheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: fg,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13)),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        Color(int.parse(note.colorHex.replaceFirst('#', '0xFF')));
    final titleColor =
        Color(int.parse(note.titleColorHex.replaceFirst('#', '0xFF')));
    final contentColor =
        Color(int.parse(note.fontColorHex.replaceFirst('#', '0xFF')));
    // Color del botón X con contraste automático sobre el fondo
    final closeColor = bgColor.computeLuminance() > 0.4
        ? Colors.black54
        : Colors.white54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: bgColor.computeLuminance() > 0.9
                ? Colors.grey.withAlpha(60)
                : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: note.fontSize.clamp(13, 18),
                      color: titleColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(Icons.close, size: 16, color: closeColor),
                ),
              ],
            ),
            if (note.labels.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: note.labels
                    .take(2)
                    .map((l) => LabelChip(label: l, small: true))
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                note.content,
                style: TextStyle(
                  fontSize: note.fontSize.clamp(11, 15),
                  color: contentColor,
                  height: 1.4,
                ),
                overflow: TextOverflow.fade,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
