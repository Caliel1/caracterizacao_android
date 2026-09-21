class CollectionSession {
  final String id;
  final DateTime startedAt;

  DateTime? endedAt;

  int flutterEvents;
  int androidEvents;

  CollectionSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.flutterEvents = 0,
    this.androidEvents = 0,
  });

  bool get isFinished => endedAt != null;

  Duration? get duration {
    if (endedAt == null) {
      return null;
    }

    return endedAt!.difference(startedAt);
  }

  Map<String, dynamic> toMap() {
    return {
      'session_id': id,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_ms': duration?.inMilliseconds,
      'flutter_events': flutterEvents,
      'android_events': androidEvents,
    };
  }
}