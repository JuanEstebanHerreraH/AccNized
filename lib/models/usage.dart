class Usage {
  final int? id;
  final int accountId;
  final String description;

  const Usage({
    this.id,
    required this.accountId,
    required this.description,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'account_id': accountId,
        'description': description,
      };

  factory Usage.fromMap(Map<String, dynamic> map) => Usage(
        id: map['id'] as int?,
        accountId: map['account_id'] as int,
        description: map['description'] as String,
      );

  Usage copyWith({int? id, int? accountId, String? description}) => Usage(
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        description: description ?? this.description,
      );
}
