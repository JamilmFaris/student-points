class Lesson {
  final int? id;
  final String date; // ISO yyyy-MM-dd
  final String subject;
  final int? remoteId;

  Lesson({this.id, required this.date, required this.subject, this.remoteId});

  factory Lesson.fromMap(Map<String, dynamic> map) => Lesson(
        id: map['id'] as int?,
        date: map['date'] as String,
        subject: (map['subject'] as String?) ?? '',
        remoteId: map['remote_id'] as int?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'date': date,
        'subject': subject,
        'remote_id': remoteId,
      };
}
