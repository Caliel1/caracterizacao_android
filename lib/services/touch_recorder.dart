import '../models/touch_event_record.dart';

class TouchRecorder {
  final List<TouchEventRecord> _events = [];

  List<TouchEventRecord> get events =>
      List.unmodifiable(_events);

  int get totalEvents => _events.length;

  int get flutterEvents => _events
      .where((event) => event.source == 'FLUTTER')
      .length;

  int get androidEvents => _events
      .where((event) => event.source == 'ANDROID')
      .length;

  void add(TouchEventRecord event) {
    _events.add(event);
  }

  void clear() {
    _events.clear();
  }

  List<TouchEventRecord> recentEvents({
    int limit = 20,
  }) {
    if (_events.isEmpty) {
      return [];
    }

    final start =
        _events.length > limit
            ? _events.length - limit
            : 0;

    return List.unmodifiable(
      _events.sublist(start),
    );
  }
}