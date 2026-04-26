import 'package:flutter/material.dart';
import '../utils/account_icons.dart';

class IconPickerDialog extends StatefulWidget {
  final String currentIcon;
  const IconPickerDialog({super.key, required this.currentIcon});

  @override
  State<IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<IconPickerDialog> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentIcon;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = kAccountIcons.entries.toList();

    return AlertDialog(
      title: const Text('Elige un icono'),
      content: SizedBox(
        width: 320,
        child: GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: entries.length,
          itemBuilder: (_, i) {
            final name = entries[i].key;
            final icon = entries[i].value;
            final isSelected = _selected == name;
            return GestureDetector(
              onTap: () => setState(() => _selected = name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: scheme.primary, width: 2)
                      : null,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? scheme.primary : scheme.onSurface,
                  size: 26,
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}
