import 'label.dart';
import 'usage.dart';

class Account {
  final int? id;
  final String identifier;
  final String type;
  final String iconName;
  final String? password;
  final String createdAt;
  List<Label> labels;
  List<Usage> usages;

  Account({
    this.id,
    required this.identifier,
    required this.type,
    this.iconName = 'account_circle',
    this.password,
    String? createdAt,
    this.labels = const [],
    this.usages = const [],
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  bool get hasPassword => password != null && password!.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'identifier': identifier,
        'type': type,
        'icon_name': iconName,
        'password': password,
        'created_at': createdAt,
      };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
        id: map['id'] as int?,
        identifier: map['identifier'] as String,
        type: map['type'] as String,
        iconName: (map['icon_name'] as String?) ?? 'account_circle',
        password: map['password'] as String?,
        createdAt: map['created_at'] as String?,
      );

  Account copyWith({
    int? id,
    String? identifier,
    String? type,
    String? iconName,
    Object? password = _sentinel,
    String? createdAt,
    List<Label>? labels,
    List<Usage>? usages,
  }) =>
      Account(
        id: id ?? this.id,
        identifier: identifier ?? this.identifier,
        type: type ?? this.type,
        iconName: iconName ?? this.iconName,
        password: password == _sentinel ? this.password : password as String?,
        createdAt: createdAt ?? this.createdAt,
        labels: labels ?? this.labels,
        usages: usages ?? this.usages,
      );
}

const _sentinel = Object();
