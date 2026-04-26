import 'label.dart';

class Note {
  final int? id;
  final String title;
  final String content;
  final String colorHex;       // fondo de la nota
  final String titleColorHex;  // color del título (independiente)
  final String fontColorHex;   // color del contenido
  final double fontSize;
  final bool isPrivate;
  final String updatedAt;
  List<Label> labels;

  Note({
    this.id,
    required this.title,
    required this.content,
    this.colorHex = '#1A1A1A',       // negro por defecto
    this.titleColorHex = '#FFFFFF',  // blanco por defecto sobre negro
    this.fontColorHex = '#E0E0E0',   // gris claro por defecto sobre negro
    this.fontSize = 16.0,
    this.isPrivate = false,
    String? updatedAt,
    this.labels = const [],
  }) : updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'color_hex': colorHex,
        'title_color_hex': titleColorHex,
        'font_color_hex': fontColorHex,
        'font_size': fontSize,
        'is_private': isPrivate ? 1 : 0,
        'updated_at': updatedAt,
      };

  factory Note.fromMap(Map<String, dynamic> map) => Note(
        id: map['id'] as int?,
        title: map['title'] as String,
        content: map['content'] as String,
        colorHex: (map['color_hex'] as String?) ?? '#1A1A1A',
        titleColorHex: (map['title_color_hex'] as String?) ?? '#FFFFFF',
        fontColorHex: (map['font_color_hex'] as String?) ?? '#E0E0E0',
        fontSize: (map['font_size'] as num?)?.toDouble() ?? 16.0,
        isPrivate: ((map['is_private'] as int?) ?? 0) == 1,
        updatedAt: map['updated_at'] as String?,
      );

  Note copyWith({
    int? id,
    String? title,
    String? content,
    String? colorHex,
    String? titleColorHex,
    String? fontColorHex,
    double? fontSize,
    bool? isPrivate,
    String? updatedAt,
    List<Label>? labels,
  }) =>
      Note(
        id: id ?? this.id,
        title: title ?? this.title,
        content: content ?? this.content,
        colorHex: colorHex ?? this.colorHex,
        titleColorHex: titleColorHex ?? this.titleColorHex,
        fontColorHex: fontColorHex ?? this.fontColorHex,
        fontSize: fontSize ?? this.fontSize,
        isPrivate: isPrivate ?? this.isPrivate,
        updatedAt: updatedAt ?? this.updatedAt,
        labels: labels ?? this.labels,
      );
}
