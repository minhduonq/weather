class Setting {
  final int? id;
  final String unit; // 'C' hoặc 'F'
  final String theme; // 'light' hoặc 'dark'
  final String language; // 'vi' hoặc 'en'
  final bool notificationEnabled;

  Setting({
    this.id,
    required this.unit,
    required this.theme,
    required this.language,
    required this.notificationEnabled,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unit': unit,
      'theme': theme,
      'language': language,
      'notification_enabled': notificationEnabled ? 1 : 0,
    };
  }

  factory Setting.fromMap(Map<String, dynamic> map) {
    return Setting(
      id: map['id'],
      unit: map['unit'],
      theme: map['theme'],
      language: map['language'],
      notificationEnabled: map['notification_enabled'] == 1,
    );
  }
}
