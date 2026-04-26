import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/note.dart';
import '../models/usage.dart';
import '../utils/account_icons.dart';
import '../widgets/label_chip.dart';
import 'account_form_screen.dart';
import 'note_editor_screen.dart';

class AccountDetailScreen extends StatefulWidget {
  final int accountId;
  const AccountDetailScreen({super.key, required this.accountId});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final _db = DatabaseHelper.instance;
  Account? _account;
  List<Note> _linkedNotes = [];
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final account = await _db.getAccount(widget.accountId);
    if (account == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    if (account.hasPassword) {
      final ok = await _showPasswordDialog(account.password!);
      if (!mounted) return;
      if (!ok) {
        Navigator.pop(context);
        return;
      }
    }

    final notes = await _db.getLinkedNotes(widget.accountId);
    if (mounted) {
      setState(() {
        _account = account;
        _linkedNotes = notes;
        _initializing = false;
      });
    }
  }

  Future<void> _reload() async {
    final account = await _db.getAccount(widget.accountId);
    final notes = await _db.getLinkedNotes(widget.accountId);
    if (mounted) setState(() {
      _account = account;
      _linkedNotes = notes;
    });
  }

  Future<bool> _showPasswordDialog(String correctPassword) async {
    final ctrl = TextEditingController();
    bool obscure = true;
    String? error;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setDlg) => AlertDialog(
              title: const Row(children: [
                Icon(Icons.lock_outline),
                SizedBox(width: 8),
                Text('Cuenta protegida'),
              ]),
              content: TextField(
                controller: ctrl,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  errorText: error,
                  suffixIcon: IconButton(
                    icon: Icon(obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setDlg(() => obscure = !obscure),
                  ),
                ),
                onSubmitted: (_) {
                  if (ctrl.text == correctPassword) {
                    Navigator.pop(ctx, true);
                  } else {
                    setDlg(() => error = 'Contraseña incorrecta');
                  }
                },
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar')),
                FilledButton(
                  onPressed: () {
                    if (ctrl.text == correctPassword) {
                      Navigator.pop(ctx, true);
                    } else {
                      setDlg(() => error = 'Contraseña incorrecta');
                    }
                  },
                  child: const Text('Entrar'),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> _addUsage() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nuevo uso'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Ej: se usa en Discord'),
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => Navigator.pop(context, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Agregar')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _db.insertUsage(
          Usage(accountId: widget.accountId, description: result));
      _reload();
    }
  }

  Future<void> _editUsage(Usage usage) async {
    final ctrl = TextEditingController(text: usage.description);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar uso'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => Navigator.pop(context, ctrl.text.trim()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await _db.updateUsage(usage.copyWith(description: result));
      _reload();
    }
  }

  /// Desvincula la nota de esta cuenta (no la elimina globalmente)
  Future<void> _unlinkNote(Note note) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Qué deseas hacer?'),
        content: Text('"${note.title}"'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'unlink'),
            child: const Text('Solo desvincular'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Eliminar nota'),
          ),
        ],
      ),
    );

    if (choice == 'unlink') {
      // Quitar solo el vínculo con esta cuenta
      final db = DatabaseHelper.instance;
      final linked = await db.getLinkedAccounts(note.id!);
      final remaining = linked
          .where((a) => a.id != widget.accountId)
          .map((a) => a.id!)
          .toList();
      await db.setLinkedAccounts(note.id!, remaining);
      _reload();
    } else if (choice == 'delete') {
      await _db.deleteNote(note.id!);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_initializing) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_account == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Cuenta no encontrada')),
      );
    }

    final account = _account!;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(account.identifier,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => AccountFormScreen(account: account)));
              _reload();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Info ──
          Card(
            color: scheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(iconFromName(account.iconName),
                        color: scheme.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(account.identifier,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(account.type,
                            style: TextStyle(color: scheme.outline)),
                      ],
                    ),
                  ),
                  if (account.hasPassword)
                    Tooltip(
                      message: 'Protegida con contraseña',
                      child: Icon(Icons.lock_outline, color: scheme.primary),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Etiquetas ──
          if (account.labels.isNotEmpty) ...[
            const _SectionHeader(title: 'Etiquetas'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  account.labels.map((l) => LabelChip(label: l)).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // ── Usos ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionHeader(title: 'Usos (${account.usages.length})'),
              IconButton.filled(
                onPressed: _addUsage,
                icon: const Icon(Icons.add, size: 18),
                style: IconButton.styleFrom(
                    iconSize: 18, minimumSize: const Size(36, 36)),
              ),
            ],
          ),
          if (account.usages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Sin usos registrados',
                  style: TextStyle(color: scheme.outline)),
            )
          else
            Card(
              color: scheme.surfaceContainerLow,
              child: Column(
                children: account.usages
                    .map((u) => ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.link,
                                size: 16, color: scheme.primary),
                          ),
                          title: Text(u.description),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                  onPressed: () => _editUsage(u)),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    size: 18, color: scheme.error),
                                onPressed: () async {
                                  await _db.deleteUsage(u.id!);
                                  _reload();
                                },
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          const SizedBox(height: 24),

          // ── Notas vinculadas ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionHeader(
                  title: 'Notas vinculadas (${_linkedNotes.length})'),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NoteEditorScreen(
                          prelinkedAccountId: widget.accountId),
                    ),
                  );
                  _reload();
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Nueva nota'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                ),
              ),
            ],
          ),
          if (_linkedNotes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Sin notas vinculadas',
                  style: TextStyle(color: scheme.outline)),
            )
          else
            ..._linkedNotes.map((note) => _LinkedNoteCard(
                  note: note,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NoteEditorScreen(note: note)),
                    );
                    _reload();
                  },
                  onRemove: () => _unlinkNote(note),
                )),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                )),
      );
}

class _LinkedNoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _LinkedNoteCard({
    required this.note,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        Color(int.parse(note.colorHex.replaceFirst('#', '0xFF')));
    // Texto siempre oscuro sobre el fondo de nota
    const textColor = Color(0xFF1A1A1A);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            if (note.isPrivate)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.lock_outline,
                    size: 16, color: textColor),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontSize: 14)),
                  if (note.content.isNotEmpty)
                    Text(note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF444444), fontSize: 12)),
                ],
              ),
            ),
            // ── Botón de eliminar/desvincular ──
            IconButton(
              icon: Icon(Icons.close,
                  size: 18,
                  color: Colors.black.withAlpha(120)),
              onPressed: onRemove,
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
