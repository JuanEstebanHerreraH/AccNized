import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/label.dart';
import '../models/note.dart';
import '../utils/account_icons.dart';
import '../widgets/label_chip.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final int? prelinkedAccountId;

  const NoteEditorScreen({super.key, this.note, this.prelinkedAccountId});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _db = DatabaseHelper.instance;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _contentCtrl;

  Note? _savedNote;
  bool _dirty = false;

  // ─── Personalización ───
  String _colorHex = '#1A1A1A';      // fondo negro por defecto
  String _titleColorHex = '#FFFFFF'; // título blanco por defecto
  String _fontColorHex = '#E0E0E0';  // contenido gris claro por defecto
  double _fontSize = 16.0;
  bool _isPrivate = false;

  // ─── Metadatos ───
  List<Label> _allLabels = [];
  Set<int> _selectedLabelIds = {};
  List<Account> _allAccounts = [];

  // FIX CRÍTICO: Se inicializa inmediatamente en initState, NO en _loadMeta
  // para evitar el race condition donde _save() se llama antes que el async
  // setState de _loadMeta termine, resultando en links vacíos o incorrectos.
  late Set<int> _linkedAccountIds;

  // Paleta fondos — oscuros primero
  static const _bgColors = [
    '#1A1A1A', '#212121', '#263238', '#1A237E',
    '#1B5E20', '#4A148C', '#B71C1C', '#37474F',
    '#FFF9C4', '#C8E6C9', '#BBDEFB', '#FFCBC1',
    '#E1BEE7', '#B2EBF2', '#FFE0B2', '#CFD8DC',
  ];

  // Paleta texto — claros primero (para fondos oscuros)
  static const _textColors = [
    '#FFFFFF', '#F5F5F5', '#E0E0E0', '#BDBDBD',
    '#FFD54F', '#80CBC4', '#EF9A9A', '#CE93D8',
    '#1A1A1A', '#333333', '#B71C1C', '#1A237E',
    '#1B5E20', '#E65100', '#4A148C', '#880E4F',
  ];

  Color get _bgColor =>
      Color(int.parse(_colorHex.replaceFirst('#', '0xFF')));
  Color get _titleColor =>
      Color(int.parse(_titleColorHex.replaceFirst('#', '0xFF')));
  Color get _contentColor =>
      Color(int.parse(_fontColorHex.replaceFirst('#', '0xFF')));

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _savedNote = note;
    _titleCtrl = TextEditingController(text: note?.title ?? '');
    _contentCtrl = TextEditingController(text: note?.content ?? '');

    if (note != null) {
      _colorHex = note.colorHex;
      _titleColorHex = note.titleColorHex;
      _fontColorHex = note.fontColorHex;
      _fontSize = note.fontSize;
      _isPrivate = note.isPrivate;
      _selectedLabelIds = note.labels
          .where((l) => l.id != null)
          .map((l) => l.id!)
          .toSet();
    }

    // FIX: inicializar linkedAccountIds SINCRÓNICAMENTE desde prelinkedAccountId
    // Así _save() siempre tiene el valor correcto aunque se llame antes de _loadMeta
    _linkedAccountIds = widget.prelinkedAccountId != null
        ? {widget.prelinkedAccountId!}
        : {};

    _titleCtrl.addListener(_markDirty);
    _contentCtrl.addListener(_markDirty);
    _loadMeta();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _loadMeta() async {
    final labels = await _db.getAllLabels();
    final accounts = await _db.getAllAccounts();

    // Cargar links existentes (solo para notas ya guardadas)
    Set<int> linkedIds = {};
    if (_savedNote?.id != null) {
      final linked = await _db.getLinkedAccounts(_savedNote!.id!);
      linkedIds = linked.where((a) => a.id != null).map((a) => a.id!).toSet();
    }
    // Agregar el prelinkedAccountId si lo hay (para notas nuevas desde cuenta)
    if (widget.prelinkedAccountId != null) {
      linkedIds.add(widget.prelinkedAccountId!);
    }

    if (mounted) {
      setState(() {
        _allLabels = labels;
        _allAccounts = accounts;
        // Solo actualizar si hay datos reales cargados (no sobreescribir con vacío)
        if (linkedIds.isNotEmpty || _savedNote?.id != null) {
          _linkedAccountIds = linkedIds;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_markDirty);
    _contentCtrl.removeListener(_markDirty);
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty && content.isEmpty) return;

    final note = Note(
      id: _savedNote?.id,
      title: title.isEmpty ? 'Sin título' : title,
      content: content,
      colorHex: _colorHex,
      titleColorHex: _titleColorHex,
      fontColorHex: _fontColorHex,
      fontSize: _fontSize,
      isPrivate: _isPrivate,
    );

    if (_savedNote == null) {
      final id = await _db.insertNote(note);
      _savedNote = note.copyWith(id: id);
    } else {
      await _db.updateNote(note.copyWith(id: _savedNote!.id));
      _savedNote = note.copyWith(id: _savedNote!.id);
    }

    await _db.setLabelsForNote(_savedNote!.id!, _selectedLabelIds.toList());
    await _db.setLinkedAccounts(
        _savedNote!.id!, _linkedAccountIds.toList());

    if (mounted) setState(() => _dirty = false);
  }

  Future<void> _saveAndPop() async {
    await _save();
    if (mounted) Navigator.pop(context);
  }

  // ─── Pickers ───

  void _showBgColorPicker() => _showColorSheet(
        title: 'Color de fondo',
        colors: _bgColors,
        selected: _colorHex,
        onSelected: (hex) => setState(() {
          _colorHex = hex;
          _dirty = true;
        }),
      );

  void _showTitleColorPicker() => _showColorSheet(
        title: 'Color del título',
        subtitle: 'Solo afecta el texto del título',
        colors: _textColors,
        selected: _titleColorHex,
        showBorder: true,
        onSelected: (hex) => setState(() {
          _titleColorHex = hex;
          _dirty = true;
        }),
      );

  void _showFontColorPicker() => _showColorSheet(
        title: 'Color del contenido',
        subtitle: 'Solo afecta el cuerpo de la nota',
        colors: _textColors,
        selected: _fontColorHex,
        showBorder: true,
        onSelected: (hex) => setState(() {
          _fontColorHex = hex;
          _dirty = true;
        }),
      );

  void _showColorSheet({
    required String title,
    String? subtitle,
    required List<String> colors,
    required ValueChanged<String> onSelected,
    String? selected,
    bool showBorder = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ColorPickerSheet(
        title: title,
        subtitle: subtitle,
        colors: colors,
        selected: selected ?? '#1A1A1A',
        showBorder: showBorder,
        onSelected: (hex) {
          onSelected(hex);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  void _showFontSizePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tamaño de texto',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Título de ejemplo',
                        style: TextStyle(
                            fontSize: _fontSize + 4,
                            fontWeight: FontWeight.bold,
                            color: _titleColor)),
                    const SizedBox(height: 4),
                    Text('Contenido de ejemplo',
                        style: TextStyle(
                            fontSize: _fontSize, color: _contentColor)),
                  ],
                ),
              ),
              Slider(
                min: 12,
                max: 28,
                divisions: 8,
                value: _fontSize,
                label: '${_fontSize.round()}px',
                onChanged: (v) {
                  setSheet(() => _fontSize = v);
                  setState(() {
                    _fontSize = v;
                    _dirty = true;
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Pequeño (12px)'),
                  Text('Grande (28px)'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Listo')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLabelsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Etiquetas',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              if (_allLabels.isEmpty)
                Text('Sin etiquetas creadas',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.outline))
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allLabels.map((label) {
                    final selected = _selectedLabelIds.contains(label.id);
                    return FilterChip(
                      label: Text(label.name),
                      selected: selected,
                      selectedColor: label.color.withAlpha(50),
                      checkmarkColor: label.color,
                      side: BorderSide(
                          color: selected
                              ? label.color
                              : Theme.of(context).colorScheme.outline),
                      onSelected: (v) {
                        setSheet(() {
                          if (v) {
                            _selectedLabelIds.add(label.id!);
                          } else {
                            _selectedLabelIds.remove(label.id!);
                          }
                        });
                        setState(() => _dirty = true);
                      },
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Listo')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sheet de vinculación con lista explícita y advertencia si hay links activos
  void _showLinkAccountsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (_, scroll) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vincular a cuentas',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'La nota aparecerá en el detalle de cada cuenta marcada.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline),
                ),
                // Aviso visual si hay cuentas vinculadas
                if (_linkedAccountIds.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link,
                            size: 16,
                            color:
                                Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Vinculada a ${_linkedAccountIds.length} cuenta(s)',
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary,
                              fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheet(
                                () => _linkedAccountIds = {});
                            setState(() {
                              _linkedAccountIds = {};
                              _dirty = true;
                            });
                          },
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero),
                          child: const Text('Limpiar todo'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: _allAccounts.isEmpty
                      ? const Center(child: Text('Sin cuentas creadas'))
                      : ListView.builder(
                          controller: scroll,
                          itemCount: _allAccounts.length,
                          itemBuilder: (_, i) {
                            final acc = _allAccounts[i];
                            final linked =
                                _linkedAccountIds.contains(acc.id);
                            return CheckboxListTile(
                              secondary: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                child: Icon(
                                    iconFromName(acc.iconName),
                                    size: 20,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary),
                              ),
                              title: Text(acc.identifier,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(acc.type,
                                  style:
                                      const TextStyle(fontSize: 12)),
                              value: linked,
                              onChanged: (v) {
                                setSheet(() {
                                  if (v == true) {
                                    _linkedAccountIds.add(acc.id!);
                                  } else {
                                    _linkedAccountIds.remove(acc.id!);
                                  }
                                });
                                setState(() {
                                  if (v == true) {
                                    _linkedAccountIds.add(acc.id!);
                                  } else {
                                    _linkedAccountIds.remove(acc.id!);
                                  }
                                  _dirty = true;
                                });
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Confirmar')),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop && _dirty) await _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _dirty
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 8, color: scheme.primary),
                  const SizedBox(width: 6),
                  const Text('Sin guardar', style: TextStyle(fontSize: 14)),
                ])
              : null,
          actions: [
            if (_isPrivate)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Tooltip(
                  message: 'Nota privada',
                  child: Icon(Icons.lock_outline, size: 20),
                ),
              ),
            if (_linkedAccountIds.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Tooltip(
                  message:
                      'Vinculada a ${_linkedAccountIds.length} cuenta(s)',
                  child: const Icon(Icons.link, size: 20),
                ),
              ),
            FilledButton.icon(
              onPressed: _saveAndPop,
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Guardar'),
            ),
            const SizedBox(width: 10),
          ],
        ),
        body: Column(
          children: [
            // ── Área de edición con fondo de nota ──
            Expanded(
              child: Container(
                color: _bgColor,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  children: [
                    // Título con SU PROPIO color
                    TextField(
                      controller: _titleCtrl,
                      style: TextStyle(
                        fontSize: _fontSize + 4,
                        fontWeight: FontWeight.bold,
                        color: _titleColor, // ← color propio del título
                      ),
                      decoration: InputDecoration(
                        hintText: 'Título',
                        hintStyle:
                            TextStyle(color: _titleColor.withAlpha(80)),
                        border: InputBorder.none,
                        filled: false,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                    ),
                    Divider(color: _titleColor.withAlpha(40)),

                    // Etiquetas activas
                    if (_selectedLabelIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 6,
                            children: _allLabels
                                .where((l) =>
                                    _selectedLabelIds.contains(l.id))
                                .map((l) =>
                                    LabelChip(label: l, small: true))
                                .toList(),
                          ),
                        ),
                      ),

                    // Contenido con su propio color
                    Expanded(
                      child: TextField(
                        controller: _contentCtrl,
                        style: TextStyle(
                          fontSize: _fontSize,
                          color: _contentColor, // ← color propio del contenido
                          height: 1.6,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Escribe aquí...',
                          hintStyle: TextStyle(
                              color: _contentColor.withAlpha(80)),
                          border: InputBorder.none,
                          filled: false,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Barra de herramientas ──
            Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                border:
                    Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ToolButton(
                        icon: Icons.palette_outlined,
                        label: 'Fondo',
                        dotColor: _bgColor,
                        onTap: _showBgColorPicker,
                      ),
                      _ToolButton(
                        icon: Icons.title,
                        label: 'Título',
                        dotColor: _titleColor,
                        onTap: _showTitleColorPicker,
                      ),
                      _ToolButton(
                        icon: Icons.format_color_text,
                        label: 'Texto',
                        dotColor: _contentColor,
                        onTap: _showFontColorPicker,
                      ),
                      _ToolButton(
                        icon: Icons.text_fields,
                        label: 'Tamaño',
                        onTap: _showFontSizePicker,
                      ),
                      _ToolButton(
                        icon: Icons.label_outline,
                        label: 'Etiquetas',
                        badge: _selectedLabelIds.isNotEmpty
                            ? _selectedLabelIds.length.toString()
                            : null,
                        onTap: _showLabelsSheet,
                      ),
                      _ToolButton(
                        icon: Icons.link,
                        label: _linkedAccountIds.isEmpty
                            ? 'Cuentas'
                            : 'Cuentas (${_linkedAccountIds.length})',
                        badge: _linkedAccountIds.isNotEmpty
                            ? _linkedAccountIds.length.toString()
                            : null,
                        active: _linkedAccountIds.isNotEmpty,
                        onTap: _showLinkAccountsSheet,
                      ),
                      _ToolButton(
                        icon: _isPrivate
                            ? Icons.lock
                            : Icons.lock_open_outlined,
                        label: _isPrivate ? 'Privada' : 'Pública',
                        active: _isPrivate,
                        onTap: () => setState(() {
                          _isPrivate = !_isPrivate;
                          _dirty = true;
                        }),
                      ),
                    ],
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

// ── Botón de herramienta ──

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final Color? dotColor;
  final bool active;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
    this.dotColor,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = active ? scheme.primary : scheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 22),
                if (dotColor != null)
                  Positioned(
                    right: -4,
                    bottom: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: scheme.surfaceContainer, width: 1),
                      ),
                    ),
                  ),
                if (badge != null)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(badge!,
                          style: const TextStyle(
                              fontSize: 9, color: Colors.white)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(label,
                style:
                    TextStyle(fontSize: 9, color: color.withAlpha(200))),
          ],
        ),
      ),
    );
  }
}

// ── Sheet de color con hex personalizado ──

class _ColorPickerSheet extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<String> colors;
  final String selected;
  final bool showBorder;
  final ValueChanged<String> onSelected;

  const _ColorPickerSheet({
    required this.title,
    this.subtitle,
    required this.colors,
    required this.selected,
    required this.showBorder,
    required this.onSelected,
  });

  @override
  State<_ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<_ColorPickerSheet> {
  late String _current;
  final _hexCtrl = TextEditingController();
  String? _hexError;

  @override
  void initState() {
    super.initState();
    _current = widget.selected;
    _hexCtrl.text = widget.selected.replaceFirst('#', '');
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  bool _isValidHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length != 6) return false;
    return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(clean);
  }

  void _applyHex() {
    final raw = _hexCtrl.text.trim();
    final hex = raw.startsWith('#') ? raw : '#$raw';
    if (_isValidHex(hex)) {
      setState(() {
        _current = hex.toUpperCase();
        _hexError = null;
      });
    } else {
      setState(() => _hexError = 'Escribe 6 caracteres hex válidos');
    }
  }

  Color _colorOf(String hex) =>
      Color(int.parse(hex.replaceFirst('#', '0xFF')));
  Color _contrastOf(Color bg) =>
      bg.computeLuminance() > 0.4 ? Colors.black : Colors.white;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            if (widget.subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(widget.subtitle!,
                    style: TextStyle(
                        fontSize: 12, color: scheme.outline)),
              ),
            const SizedBox(height: 20),

            // Paleta predefinida
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: widget.colors.map((hex) {
                final color = _colorOf(hex);
                final isSel =
                    _current.toUpperCase() == hex.toUpperCase();
                return GestureDetector(
                  onTap: () => setState(() {
                    _current = hex.toUpperCase();
                    _hexCtrl.text = hex.replaceFirst('#', '');
                    _hexError = null;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel
                            ? scheme.primary
                            : widget.showBorder
                                ? Colors.grey.withAlpha(80)
                                : Colors.transparent,
                        width: isSel ? 3 : 1,
                      ),
                      boxShadow: isSel
                          ? [
                              BoxShadow(
                                  color: color.withAlpha(120),
                                  blurRadius: 8)
                            ]
                          : null,
                    ),
                    child: isSel
                        ? Icon(Icons.check,
                            size: 20, color: _contrastOf(color))
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Preview + input hex
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _colorOf(_current),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Center(
                    child: Text('Aa',
                        style: TextStyle(
                            color: _contrastOf(_colorOf(_current)),
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hex personalizado',
                          style: TextStyle(
                              fontSize: 12, color: scheme.outline)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _hexCtrl,
                        decoration: InputDecoration(
                          prefixText: '#',
                          hintText: 'Ej: FF5722',
                          errorText: _hexError,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9A-Fa-f]')),
                          LengthLimitingTextInputFormatter(6),
                        ],
                        textCapitalization: TextCapitalization.characters,
                        onSubmitted: (_) => _applyHex(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _applyHex,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('OK'),
                ),
              ],
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => widget.onSelected(_current),
                child: const Text('Confirmar color'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
