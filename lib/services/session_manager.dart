import '../models/collection_session.dart';
import 'touch_recorder.dart';

class SessionManager {
  CollectionSession? _currentSession;

  CollectionSession? get currentSession =>
      _currentSession;

  bool get isCollecting =>
      _currentSession != null &&
      !_currentSession!.isFinished;

  void start(
    TouchRecorder recorder,
  ) {
    recorder.clear();

    final now = DateTime.now();

    _currentSession =
        CollectionSession(
      id: _generateSessionId(now),
      startedAt: now,
    );
  }

  CollectionSession? finish(
    TouchRecorder recorder,
  ) {
    if (_currentSession == null) {
      return null;
    }

    if (_currentSession!.isFinished) {
      return _currentSession;
    }

    final now = DateTime.now();

    _currentSession!.endedAt = now;

    _currentSession!.flutterEvents =
        recorder.flutterEvents;

    _currentSession!.androidEvents =
        recorder.androidEvents;

    return _currentSession;
  }

  void updateCounts(
    TouchRecorder recorder,
  ) {
    if (_currentSession == null) {
      return;
    }

    _currentSession!.flutterEvents =
        recorder.flutterEvents;

    _currentSession!.androidEvents =
        recorder.androidEvents;
  }

  String _generateSessionId(
    DateTime dateTime,
  ) {
    String twoDigits(int value) {
      return value
          .toString()
          .padLeft(2, '0');
    }

    String threeDigits(int value) {
      return value
          .toString()
          .padLeft(3, '0');
    }

    return '${dateTime.year}'
        '${twoDigits(dateTime.month)}'
        '${twoDigits(dateTime.day)}_'
        '${twoDigits(dateTime.hour)}'
        '${twoDigits(dateTime.minute)}'
        '${twoDigits(dateTime.second)}_'
        '${threeDigits(dateTime.millisecond)}';
  }
}