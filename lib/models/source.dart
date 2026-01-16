import 'quote.dart';

class Source {
  final String id;
  final String title;
  final String author;
  final int year;
  final String? publisher;
  final String filePath;
  final DateTime createdAt;
  List<Quote> quotes;

  Source({
    required this.id,
    required this.title,
    required this.author,
    required this.year,
    this.publisher,
    required this.filePath,
    required this.createdAt,
    List<Quote>? quotes,
  }) : quotes = quotes ?? [];

  String get citation {
    final pub = publisher != null ? ' $publisher.' : '';
    return '"$title" by $author ($year).$pub';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'year': year,
        'publisher': publisher,
        'filePath': filePath,
        'createdAt': createdAt.toIso8601String(),
        'quotes': quotes.map((q) => q.toJson()).toList(),
      };

  factory Source.fromJson(Map<String, dynamic> json) => Source(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String,
        year: json['year'] as int,
        publisher: json['publisher'] as String?,
        filePath: json['filePath'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        quotes: (json['quotes'] as List<dynamic>?)
                ?.map((q) => Quote.fromJson(q as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Source copyWith({
    String? id,
    String? title,
    String? author,
    int? year,
    String? publisher,
    String? filePath,
    DateTime? createdAt,
    List<Quote>? quotes,
  }) =>
      Source(
        id: id ?? this.id,
        title: title ?? this.title,
        author: author ?? this.author,
        year: year ?? this.year,
        publisher: publisher ?? this.publisher,
        filePath: filePath ?? this.filePath,
        createdAt: createdAt ?? this.createdAt,
        quotes: quotes ?? this.quotes,
      );
}
