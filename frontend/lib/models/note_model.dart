class Note {
  int? id;
  String content;
  DateTime reminderTime;
  double humidity;
  double temperature;
  String location;
  String weatherDescription;
  String windSpeed;

  Note({
    this.id,
    required this.content,
    required this.reminderTime,
    required this.humidity,
    required this.temperature,
    required this.location,
    required this.weatherDescription,
    required this.windSpeed,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'reminderTime': reminderTime.toIso8601String(),
      'humidity': humidity,
      'temperature': temperature,
      'location': location,
      'weatherDescription': weatherDescription,
      'windSpeed': windSpeed,
    };
  }

  factory Note.fromMap(Map<String, dynamic> map) {
    return Note(
      id: map['id'],
      content: map['content'],
      reminderTime: DateTime.parse(map['reminderTime']),
      humidity: map['humidity'],
      temperature: map['temperature'],
      location: map['location'],
      weatherDescription: map['weatherDescription'],
      windSpeed: map['windSpeed'],
    );
  }
}
