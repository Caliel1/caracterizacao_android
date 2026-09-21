import 'dart:math' as math;

import '../models/touch_analysis_result.dart';
import '../models/touch_event_record.dart';

class TouchAnalysisService {
  TouchAnalysisResult analyze({
    required String source,
    required List<TouchEventRecord> events,
  }) {
    final sourceEvents = events
        .where(
          (event) =>
              event.source == source,
        )
        .toList();

    // ==========================================================
    // TIMESTAMPS ÚNICOS
    // ==========================================================
    //
    // Um MotionEvent com 3 dedos gera vários registros no nosso
    // TouchRecorder, mas todos pertencem ao mesmo evento temporal.
    //
    // Portanto, usamos um timestamp uma única vez.
    // ==========================================================

    final uniqueTimestamps =
        <int>{};

    for (final event in sourceEvents) {
      uniqueTimestamps.add(
        event.timestamp,
      );
    }

    final timestamps =
        uniqueTimestamps.toList()
          ..sort();

    final intervalsMs =
        <double>[];

    for (int i = 1;
        i < timestamps.length;
        i++) {
      final rawDelta =
          timestamps[i] -
          timestamps[i - 1];

      final deltaMs =
          _toMilliseconds(
        source,
        rawDelta,
      );

      if (deltaMs > 0) {
        intervalsMs.add(
          deltaMs,
        );
      }
    }

    // ==========================================================
    // TODOS OS EVENTOS
    // ==========================================================

    final durationMs =
        timestamps.length >= 2
            ? _toMilliseconds(
                source,
                timestamps.last -
                    timestamps.first,
              )
            : null;

    final mean =
        _mean(intervalsMs);

    final median =
        _median(intervalsMs);

    final standardDeviation =
        _standardDeviation(
      intervalsMs,
      mean,
    );

    final min =
        intervalsMs.isEmpty
            ? null
            : intervalsMs.reduce(math.min);

    final max =
        intervalsMs.isEmpty
            ? null
            : intervalsMs.reduce(math.max);

    final p5 =
        _percentile(
      intervalsMs,
      5,
    );

    final p95 =
        _percentile(
      intervalsMs,
      95,
    );

    final observedRate =
        median == null || median <= 0
            ? null
            : 1000.0 / median;

    // ==========================================================
    // SOMENTE MOVE
    // ==========================================================

    final moveEvents =
        sourceEvents
            .where(
              (event) =>
                  event.eventType == 'MOVE',
            )
            .toList();

    final moveTimestamps =
        <int>{};

    for (final event in moveEvents) {
      moveTimestamps.add(
        event.timestamp,
      );
    }

    final sortedMoveTimestamps =
        moveTimestamps.toList()
          ..sort();

    final moveIntervalsMs =
        <double>[];

    for (int i = 1;
        i <
            sortedMoveTimestamps.length;
        i++) {
      final rawDelta =
          sortedMoveTimestamps[i] -
          sortedMoveTimestamps[i - 1];

      final deltaMs =
          _toMilliseconds(
        source,
        rawDelta,
      );

      if (deltaMs > 0) {
        moveIntervalsMs.add(
          deltaMs,
        );
      }
    }

    final moveMedian =
        _median(moveIntervalsMs);

    final moveRate =
        moveMedian == null ||
                moveMedian <= 0
            ? null
            : 1000.0 / moveMedian;

    return TouchAnalysisResult(
      source: source,

      totalRecords:
          sourceEvents.length,

      uniqueEvents:
          timestamps.length,

      intervalCount:
          intervalsMs.length,

      durationMs:
          durationMs,

      meanDeltaMs:
          mean,

      medianDeltaMs:
          median,

      standardDeviationMs:
          standardDeviation,

      minDeltaMs:
          min,

      maxDeltaMs:
          max,

      percentile5Ms:
          p5,

      percentile95Ms:
          p95,

      observedRateHz:
          observedRate,

      moveEventCount:
          moveEvents.length,

      moveMedianDeltaMs:
          moveMedian,

      moveObservedRateHz:
          moveRate,
    );
  }

  // ==========================================================
  // CONVERSÃO DE TIMESTAMP
  // ==========================================================

  double _toMilliseconds(
    String source,
    int delta,
  ) {
    if (source == 'FLUTTER') {
      // Flutter: microssegundos → milissegundos.
      return delta / 1000.0;
    }

    // Android: milissegundos.
    return delta.toDouble();
  }

  // ==========================================================
  // MÉDIA
  // ==========================================================

  double? _mean(
    List<double> values,
  ) {
    if (values.isEmpty) {
      return null;
    }

    final sum =
        values.reduce(
          (a, b) => a + b,
        );

    return sum / values.length;
  }

  // ==========================================================
  // MEDIANA
  // ==========================================================

  double? _median(
    List<double> values,
  ) {
    if (values.isEmpty) {
      return null;
    }

    final sorted =
        List<double>.from(values)
          ..sort();

    final middle =
        sorted.length ~/ 2;

    if (sorted.length.isOdd) {
      return sorted[middle];
    }

    return (
            sorted[middle - 1] +
                sorted[middle]
          ) /
          2.0;
  }

  // ==========================================================
  // DESVIO PADRÃO
  // ==========================================================

  double? _standardDeviation(
    List<double> values,
    double? mean,
  ) {
    if (values.isEmpty ||
        mean == null) {
      return null;
    }

    final squaredDifferences =
        values.map(
      (value) {
        final difference =
            value - mean;

        return difference *
            difference;
      },
    );

    final variance =
        squaredDifferences.reduce(
              (a, b) => a + b,
            ) /
            values.length;

    return math.sqrt(
      variance,
    );
  }

  // ==========================================================
  // PERCENTIL
  // ==========================================================

  double? _percentile(
    List<double> values,
    double percentile,
  ) {
    if (values.isEmpty) {
      return null;
    }

    final sorted =
        List<double>.from(values)
          ..sort();

    if (sorted.length == 1) {
      return sorted.first;
    }

    final position =
        (percentile / 100) *
            (sorted.length - 1);

    final lower =
        position.floor();

    final upper =
        position.ceil();

    if (lower == upper) {
      return sorted[lower];
    }

    final weight =
        position - lower;

    return sorted[lower] +
        (sorted[upper] -
                sorted[lower]) *
            weight;
  }
}