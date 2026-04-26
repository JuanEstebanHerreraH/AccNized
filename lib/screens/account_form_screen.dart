import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/account.dart';
import '../models/label.dart';
import '../models/usage.dart';
import '../widgets/icon_picker_dialog.dart';
import '../utils/account_icons.dart';

class AccountFormScreen extends StatefulWidget {
  final Account? account;
  const AccountFormScreen({super.key, this.account});

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;

  late final TextEditingController _identifierCtrl;
  late final TextEditingController _typeCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _confirmPasswordCtrl;

  String _selectedIcon = 'account_circle';
  List<Label> _allLabels = [];
  Set<int> _selectedLabelIds = {};
  List<_UsageEntry> _usages = [];
  bool _isEdit = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _hasPassword = false;

  static const _accountTypes = [
    'Gmail', 'Google', 'Facebook', 'Instagram', 'Twitter / X',
    'LinkedIn', 'TikTok', 'GitHub', 'Microsoft', 'Apple',
    'Discord', 'Spotify', 'Amazon', 'Otro',
  ];

  @override
  void initState() {
    super.initState();
    _isEdit = widget.account != null;
    _identifierCtrl =
        TextEditingController(text: widget.account?.identifier ?? '');
    _typeCtrl = TextEditingController(text: widget.account?.type ?? '');
    _passwordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
    _selectedIcon = widget.account?.iconName ?? 'account_circle';
    _hasPassword = widget.account?.hasPassword ?? false;

    if (_isEdit) {
      _selectedLabelIds = widget.account!.labels
          .where((l) => l.id != null)
          .map((l) => l.id!)
          .toSet();
      _usages = widget.account!.usages
          .map((u) => _UsageEntry(
              id: u.id,
              controller: TextEditingController(text: u.description)))
          .toList();
    }
    _loadLabels();
  }

  Future<void> _loadLabels() async {
    final labels = await _db.getAllLabels();
    setState(() => _allLabels = labels);
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _typeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    for (final u in _usages) {
      u.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => IconPickerDialog(currentIcon: _selectedIcon),
    );
    if (result != null) setState(() => _selectedIcon = result);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validar contraseña si nueva
    String? finalPassword;
    if (_isEdit && widget.account!.hasPassword && !_hasPassword) {
      // Quitando contraseña - ok
      finalPassword = null;
    } else if (_passwordCtrl.text.isNotEmpty) {
      if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Las contraseñas no coinciden')),
        );
        return;
      }
      finalPassword = _passwordCtrl.text;
    } else if (_isEdit) {
      finalPassword = widget.account!.password;
    }

    final identifier = _identifierCtrl.text.trim();
    final type = _typeCtrl.text.trim();

    int accountId;

    if (_isEdit) {
      final updated = Account(
        id: widget.account!.id,
        identifier: identifier,
        type: type,
        iconName: _selectedIcon,
        password: finalPassword,
        createdAt: widget.account!.createdAt,
      );
      await _db.updateAccount(updated);
      accountId = widget.account!.id!;

      final existingIds = widget.account!.usages
          .map((u) => u.id)
          .whereType<int>()
          .toSet();
      final currentIds =
          _usages.where((u) => u.id != null).map((u) => u.id!).toSet();
      for (final id in existingIds.difference(currentIds)) {
        await _db.deleteUsage(id);
      }
      for (final entry in _usages) {
        final desc = entry.controller.text.trim();
        if (desc.isEmpty) continue;
        if (entry.id != null) {
          await _db.updateUsage(
              Usage(id: entry.id, accountId: accountId, description: desc));
        } else {
          await _db.insertUsage(
              Usage(accountId: accountId, description: desc));
        }
      }
    } else {
      final account = Account(
        identifier: identifier,
        type: type,
        iconName: _selectedIcon,
        password: finalPassword,
      );
      accountId = await _db.insertAccount(account);
      for (final entry in _usages) {
        final desc = entry.controller.text.trim();
        if (desc.isNotEmpty) {
          await _db.insertUsage(
              Usage(accountId: accountId, description: desc));
        }
      }
    }

    await _db.setLabelsForAccount(accountId, _selectedLabelIds.toList());
    if (mounted) Navigator.pop(context);
  }

  void _addUsageField() => setState(
      () => _usages.add(_UsageEntry(controller: TextEditingController())));

  void _removeUsageField(int index) {
    _usages[index].controller.dispose();
    setState(() => _usages.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar cuenta' : 'Nueva cuenta',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          FilledButton(onPressed: _save, child: const Text('Guardar')),
          const SizedBox(width: 12),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Icono personalizado ──
            Center(
              child: GestureDetector(
                onTap: _pickIcon,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(iconFromName(_selectedIcon),
                            size: 38, color: scheme.primary),
                      ),
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.edit,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _pickIcon,
                icon: const Icon(Icons.palette_outlined, size: 16),
                label: const Text('Cambiar icono'),
              ),
            ),
            const SizedBox(height: 16),

            // ── Identificador ──
            TextFormField(
              controller: _identifierCtrl,
              decoration: const InputDecoration(
                labelText: 'Correo / Identificador *',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 16),

            // ── Tipo ──
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _typeCtrl.text),
              optionsBuilder: (v) => _accountTypes.where(
                  (t) => t.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (s) => _typeCtrl.text = s,
              fieldViewBuilder: (ctx, ctrl, fn, onFieldSubmitted) {
                ctrl.text = _typeCtrl.text;
                ctrl.addListener(() => _typeCtrl.text = ctrl.text);
                return TextFormField(
                  controller: ctrl,
                  focusNode: fn,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de cuenta *',
                    prefixIcon: Icon(Icons.account_circle_outlined),
                    hintText: 'Gmail, Facebook, etc.',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Campo requerido' : null,
                  onFieldSubmitted: (_) => onFieldSubmitted(),
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Contraseña ──
            _SectionTitle(title: 'Contraseña (opcional)'),
            if (_isEdit && widget.account!.hasPassword && _passwordCtrl.text.isEmpty)
              SwitchListTile(
                title: const Text('Cuenta protegida con contraseña'),
                subtitle: const Text('Desactiva para quitar la contraseña'),
                value: _hasPassword,
                onChanged: (v) => setState(() => _hasPassword = v),
                contentPadding: EdgeInsets.zero,
              ),
            if (!_isEdit ||
                !widget.account!.hasPassword ||
                !_hasPassword ||
                _passwordCtrl.text.isNotEmpty) ...[
              TextFormField(
                controller: _passwordCtrl,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  labelText: _isEdit && widget.account!.hasPassword
                      ? 'Nueva contraseña (dejar vacío para mantener)'
                      : 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _showPassword = !_showPassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordCtrl,
                obscureText: !_showConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_showConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                    onPressed: () =>
                        setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
                validator: (v) {
                  if (_passwordCtrl.text.isNotEmpty && v != _passwordCtrl.text) {
                    return 'Las contraseñas no coinciden';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),

            // ── Etiquetas ──
            _SectionTitle(title: 'Etiquetas'),
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
                      color: selected ? label.color : scheme.outline),
                  onSelected: (v) => setState(() {
                    if (v) {
                      _selectedLabelIds.add(label.id!);
                    } else {
                      _selectedLabelIds.remove(label.id!);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── Usos ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SectionTitle(title: 'Usos'),
                TextButton.icon(
                  onPressed: _addUsageField,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            if (_usages.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Toca "Agregar" para añadir un uso',
                    style: TextStyle(color: scheme.outline, fontSize: 13)),
              )
            else
              ...List.generate(_usages.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _usages[i].controller,
                          decoration: InputDecoration(
                            labelText: 'Uso ${i + 1}',
                            hintText: 'Ej: se usa en Discord',
                            prefixIcon: const Icon(Icons.link, size: 20),
                          ),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            color: scheme.error),
                        onPressed: () => _removeUsageField(i),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                )),
      );
}

class _UsageEntry {
  final int? id;
  final TextEditingController controller;
  _UsageEntry({this.id, required this.controller});
}
