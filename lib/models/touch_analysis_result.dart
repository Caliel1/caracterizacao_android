class TouchAnalysisResult {
  final String source;

  final int totalRecords;
  final int uniqueEvents;

  final int intervalCount;

  final double? durationMs;

  final double? meanDeltaMs;
  final double? medianDeltaMs;
  final double? standardDeviationMs;

  final double? minDeltaMs;
  final double? maxDeltaMs;

  final double? percentile5Ms;
  final double? percentile95Ms;

  final double? observedRateHz;

  final int moveEventCount;
  final double? moveMedianDeltaMs;
  final double? moveObservedRateHz;

  TouchAnalysisResult({
    required this.source,
    required this.totalRecords,
    required this.uniqueEvents,
    required this.intervalCount,
    required this.durationMs,
    required this.meanDeltaMs,
    required this.medianDeltaMs,
    required this.standardDeviationMs,
    required this.minDeltaMs,
    required this.maxDeltaMs,
    required this.percentile5Ms,
    required this.percentile95Ms,
    required this.observedRateHz,
    required this.moveEventCount,
    required this.moveMedianDeltaMs,
    required this.moveObservedRateHz,
  });
}