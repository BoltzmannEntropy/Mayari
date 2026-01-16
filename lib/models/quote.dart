class Quote {
  final String id;
  final String sourceId;
  final String text;
  final int pageNumber;
  final String? notes;
  final DateTime createdAt;
  int order;

  Quote({
    required this.id,
    required this.sourceId,
    required this.text,
    required this.pageNumber,
    this.notes,
    required this.createdAt,
    this.order = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceId': sourceId,
        'text': text,
        'pageNumber': pageNumber,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'order': order,
      };

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        id: json['id'] as String,
        sourceId: json['sourceId'] as String,
        text: json['text'] as String,
        pageNumber: json['pageNumber'] as int,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        order: json['order'] as int? ?? 0,
      );

  Quote copyWith({
    String? id,
    String? sourceId,
    String? text,
    int? pageNumber,
    String? notes,
    DateTime? createdAt,
    int? order,
  }) =>
      Quote(
        id: id ?? this.id,
        sourceId: sourceId ?? this.sourceId,
        text: text ?? this.text,
        pageNumber: pageNumber ?? this.pageNumber,
        notes: notes ?? this.notes,
        createdAt: createdAt ?? this.createdAt,
        order: order ?? this.order,
      );
}
