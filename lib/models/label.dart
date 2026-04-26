import 'package:flutter/material.dart';

class Label {
  final int? id;
  final String name;
  final String colorHex;
  final bool isDefault;

  const Label({
    this.id,
    required this.name,
    required this.colorHex,
    this.isDefault = false,
  });

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'color_hex': colorHex,
        'is_default': isDefault ? 1 : 0,
      };

  factory Label.fromMap(Map<String, dynamic> map) => Label(
        id: map['id'] as int?,
        name: map['name'] as String,
        colorHex: map['color_hex'] as String,
        isDefault: (map['is_default'] as int) == 1,
      );

  Label copyWith({int? id, String? name, String? colorHex, bool? isDefault}) =>
      Label(
        id: id ?? this.id,
        name: name ?? this.name,
        colorHex: colorHex ?? this.colorHex,
        isDefault: isDefault ?? this.isDefault,
      );

  static const List<Label> defaults = [
    Label(name: 'Importante', colorHex: '#F44336', isDefault: true),
    Label(name: 'Personal', colorHex: '#2196F3', isDefault: true),
    Label(name: 'Trabajo', colorHex: '#4CAF50', isDefault: true),
  ];
}
