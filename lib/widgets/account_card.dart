import 'package:flutter/material.dart';
import '../models/account.dart';
import '../utils/account_icons.dart';
import 'label_chip.dart';

class AccountCard extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AccountCard({
    super.key,
    required this.account,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = account.hasPassword;

    return Card(
      color: scheme.surfaceContainerLow,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // ── Icono ──
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            iconFromName(account.iconName),
                            color: scheme.primary,
                            size: 24,
                          ),
                        ),
                        if (locked)
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: Icon(Icons.lock,
                                size: 11, color: scheme.primary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),

                  // ── Nombre y tipo (siempre visible) ──
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.identifier,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(account.type,
                            style: TextStyle(
                                color: scheme.outline, fontSize: 13)),
                      ],
                    ),
                  ),

                  // ── Menú ──
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error),
                          title: Text('Eliminar',
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error)),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Contenido oculto si tiene contraseña ──
              if (locked) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 13, color: scheme.outline),
                    const SizedBox(width: 6),
                    Text(
                      'Contenido protegido',
                      style: TextStyle(
                          fontSize: 12,
                          color: scheme.outline,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ] else ...[
                // Etiquetas
                if (account.labels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: account.labels
                        .map((l) => LabelChip(label: l, small: true))
                        .toList(),
                  ),
                ],
                // Usos (preview)
                if (account.usages.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.link, size: 14, color: scheme.outline),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          account.usages.length == 1
                              ? account.usages.first.description
                              : '${account.usages.first.description} +${account.usages.length - 1} más',
                          style: TextStyle(
                              fontSize: 12, color: scheme.outline),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
