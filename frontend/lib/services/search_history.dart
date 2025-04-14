class SearchHistory {
  final int? id;
  final String location;
  final DateTime searchedAt;

  SearchHistory({
    this.id,
    required this.location,
    required this.searchedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'location': location,
      'searched_at': searchedAt.toIso8601String(),
    };
  }

  factory SearchHistory.fromMap(Map<String, dynamic> map) {
    return SearchHistory(
      id: map['id'],
      location: map['location'],
      searchedAt: DateTime.parse(map['searched_at']),
    );
  }
}
