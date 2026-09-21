import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/collection_session.dart';
import '../models/touch_analysis_result.dart';
import '../models/touch_event_record.dart';
import '../models/device_characterization.dart';
import '../services/csv_service.dart';
import '../services/session_manager.dart';
import '../services/touch_analysis_service.dart';
import '../services/touch_recorder.dart';
import '../services/device_characterization_service.dart';

class TouchPage extends StatefulWidget {
  const TouchPage({super.key});

  @override
  State<TouchPage> createState() => _TouchPageState();
}

class _TouchPageState extends State<TouchPage> {
  // ===========================================================================
  // SERVIÇOS
  // ===========================================================================

  final TouchRecorder _recorder = TouchRecorder();
  final SessionManager _sessionManager = SessionManager();
  final CsvService _csvService = CsvService();
  final TouchAnalysisService _analysisService =
      TouchAnalysisService();
  
  final DeviceCharacterizationService
    _deviceCharacterizationService =
    DeviceCharacterizationService();

  DeviceCharacterization?
      _deviceCharacterization;

  // ===========================================================================
  // CANAL NATIVO ANDROID
  // ===========================================================================

  static const EventChannel _nativeTouchChannel =
      EventChannel('caracterizacao_android/native_touch');

  StreamSubscription<dynamic>? _nativeTouchSubscription;

  // ===========================================================================
  // ÁREA EXPERIMENTAL
  // ===========================================================================

  final GlobalKey _touchAreaKey = GlobalKey();

  // Ponteiros atualmente ativos no Flutter.
  final Map<int, Offset> _activeFlutterPointers = {};

  // Ponteiros Android capturados dentro da área experimental.
  final Set<int> _capturedAndroidPointers = {};

  // ===========================================================================
  // CONTADORES DE EVENTOS
  // ===========================================================================

  final Map<String, int> _eventTypeCounts = {
    'DOWN': 0,
    'POINTER_DOWN': 0,
    'POINTER_UP': 0,
    'UP': 0,
    'CANCEL': 0,
    'MOVE': 0,
  };

  // Sequência dos eventos mais recentes.
  final List<String> _eventSequence = [];

  // ===========================================================================
  // ÚLTIMO EVENTO RAW
  // ===========================================================================

  String _lastSource = '-';
  String _lastEventType = '-';

  int? _lastPointerId;
  int _lastPointerCount = 0;

  double? _lastX;
  double? _lastY;
  double? _lastPressure;
  double? _lastSize;

  // ===========================================================================
  // ÚLTIMA TRANSIÇÃO
  //
  // MOVE não sobrescreve estes campos.
  // ===========================================================================

  String _lastTransitionSource = '-';
  String _lastTransitionType = '-';

  // ===========================================================================
  // CONTADORES GERAIS
  // ===========================================================================

  int _displayedFlutterEvents = 0;
  int _displayedAndroidEvents = 0;

  // ===========================================================================
  // CICLO DE VIDA
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _subscribeToNativeTouch();
  }

  @override
  void dispose() {
    _nativeTouchSubscription?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // CANAL ANDROID
  // ===========================================================================

  void _subscribeToNativeTouch() {
    _nativeTouchSubscription =
        _nativeTouchChannel.receiveBroadcastStream().listen(
      _onNativeTouch,
      onError: (dynamic error) {},
    );
  }

  // ===========================================================================
  // CONVERSÃO
  // ===========================================================================

  int? _toInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString());
  }

  double? _toDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  // ===========================================================================
  // FLUTTER - DOWN
  // ===========================================================================

  void _onPointerDown(
    PointerDownEvent event,
  ) {
    final bool isFirstPointer =
        _activeFlutterPointers.isEmpty;

    _activeFlutterPointers[event.pointer] =
        event.localPosition;

    final String eventType =
        isFirstPointer
            ? 'DOWN'
            : 'POINTER_DOWN';

    debugPrint(
      'FLUTTER DOWN: '
      'pointer=${event.pointer} '
      'ativos=${_activeFlutterPointers.keys.toList()} '
      'tipo=$eventType',
    );

    _processFlutterEvent(
      event,
      eventType,
    );

    if (mounted) {
      setState(() {});
    }
  }

  // ===========================================================================
  // FLUTTER - MOVE
  // ===========================================================================

  void _onPointerMove(
    PointerMoveEvent event,
  ) {
    _activeFlutterPointers[event.pointer] =
        event.localPosition;

    _processFlutterEvent(
      event,
      'MOVE',
    );

    if (mounted) {
      setState(() {});
    }
  }

  // ===========================================================================
  // FLUTTER - UP
  // ===========================================================================

  void _onPointerUp(
    PointerUpEvent event,
  ) {
    final bool hasOtherPointers =
        _activeFlutterPointers.keys.any(
      (id) => id != event.pointer,
    );

    final String eventType =
        hasOtherPointers
            ? 'POINTER_UP'
            : 'UP';

    debugPrint(
      'FLUTTER UP: '
      'pointer=${event.pointer} '
      'ativosAntes=${_activeFlutterPointers.keys.toList()} '
      'tipo=$eventType',
    );

    _processFlutterEvent(
      event,
      eventType,
    );

    _activeFlutterPointers.remove(
      event.pointer,
    );

    debugPrint(
      'FLUTTER APÓS UP: '
      'ativos=${_activeFlutterPointers.keys.toList()}',
    );

    if (mounted) {
      setState(() {});
    }
  }

  // ===========================================================================
  // FLUTTER - CANCEL
  // ===========================================================================

  void _onPointerCancel(
    PointerCancelEvent event,
  ) {
    debugPrint(
      'FLUTTER CANCEL: '
      'pointer=${event.pointer} '
      'ativosAntes=${_activeFlutterPointers.keys.toList()}',
    );

    _processFlutterEvent(
      event,
      'CANCEL',
    );

    _activeFlutterPointers.remove(
      event.pointer,
    );

    debugPrint(
      'FLUTTER APÓS CANCEL: '
      'ativos=${_activeFlutterPointers.keys.toList()}',
    );

    if (mounted) {
      setState(() {});
    }
  }

  // ===========================================================================
  // PROCESSAMENTO DO EVENTO FLUTTER
  // ===========================================================================

  void _processFlutterEvent(
    PointerEvent event,
    String eventType,
  ) {
    final TouchEventRecord record =
        TouchEventRecord(
      source: 'FLUTTER',
      eventType: eventType,
      timestamp:
          event.timeStamp.inMicroseconds,
      pointerIndex: 0,
      pointerId: event.pointer,
      pointerCount:
          _activeFlutterPointers.length,
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      deltaX: event.delta.dx,
      deltaY: event.delta.dy,
      pressure: event.pressure,
      size: event.size,
      touchMajor: event.radiusMajor,
      touchMinor: event.radiusMinor,
      toolMajor: null,
      toolMinor: null,
    );

    _recorder.add(record);

    _updateCurrentState(
      source: record.source,
      eventType: record.eventType,
      pointerId: record.pointerId,
      pointerCount: record.pointerCount,
      x: record.x,
      y: record.y,
      pressure: record.pressure,
      size: record.size,
    );

    _updateSessionCounts();
  }

  // ===========================================================================
  // ANDROID
  // ===========================================================================

  void _onNativeTouch(dynamic rawData) {
    if (rawData is! Map) {
      return;
    }

    final Map<String, dynamic> data =
        Map<String, dynamic>.from(rawData);

    final String actionName =
        data['actionName']?.toString() ?? 'OTHER';

    final int actionIndex =
        _toInt(data['actionIndex']) ?? -1;

    final int timestamp =
        _toInt(data['eventTimeMs']) ?? 0;

    final List<Map<String, dynamic>> pointers = [];

    final dynamic rawPointers = data['pointers'];

    if (rawPointers is List) {
      for (final item in rawPointers) {
        if (item is Map) {
          pointers.add(
            Map<String, dynamic>.from(item),
          );
        }
      }
    }

    if (pointers.isEmpty) {
      return;
    }

    // -------------------------------------------------------------------------
    // Ponteiro correspondente ao actionIndex
    // -------------------------------------------------------------------------

    Map<String, dynamic>? actionPointer;

    if (actionIndex >= 0 &&
        actionIndex < pointers.length) {
      actionPointer =
          pointers[actionIndex];
    }

    final int? actionPointerId =
        actionPointer == null
            ? null
            : _toInt(
                actionPointer['pointerId'],
              );

    final double? actionX =
        actionPointer == null
            ? null
            : _toDouble(
                actionPointer['x'],
              );

    final double? actionY =
        actionPointer == null
            ? null
            : _toDouble(
                actionPointer['y'],
              );

    // -------------------------------------------------------------------------
    // DOWN
    // -------------------------------------------------------------------------

    if (actionName == 'DOWN') {
      if (actionPointerId == null ||
          actionX == null ||
          actionY == null) {
        return;
      }

      if (!_isAndroidPointInsideTouchArea(
        actionX,
        actionY,
      )) {
        return;
      }

      _capturedAndroidPointers.add(
        actionPointerId,
      );
    }

    // -------------------------------------------------------------------------
    // POINTER_DOWN
    // -------------------------------------------------------------------------

    if (actionName == 'POINTER_DOWN') {
      if (actionPointerId == null ||
          actionX == null ||
          actionY == null) {
        return;
      }

      if (_capturedAndroidPointers.isEmpty) {
        return;
      }

      if (!_isAndroidPointInsideTouchArea(
        actionX,
        actionY,
      )) {
        return;
      }

      _capturedAndroidPointers.add(
        actionPointerId,
      );
    }

    // -------------------------------------------------------------------------
    // MOVE
    // -------------------------------------------------------------------------

    if (actionName == 'MOVE') {
      if (_capturedAndroidPointers.isEmpty) {
        return;
      }
    }

    // -------------------------------------------------------------------------
    // POINTER_UP / UP
    // -------------------------------------------------------------------------

    if (actionName == 'POINTER_UP' ||
        actionName == 'UP') {
      if (_capturedAndroidPointers.isEmpty) {
        return;
      }
    }

    // -------------------------------------------------------------------------
    // CANCEL
    // -------------------------------------------------------------------------

    if (actionName == 'CANCEL') {
      if (_capturedAndroidPointers.isEmpty) {
        return;
      }
    }

    if (!_shouldProcessAndroidAction(
      actionName,
    )) {
      return;
    }

    if (_capturedAndroidPointers.isEmpty) {
      return;
    }

    bool updatedDisplay = false;

    // -------------------------------------------------------------------------
    // REGISTRA OS PONTEIROS CAPTURADOS
    // -------------------------------------------------------------------------

    for (int index = 0;
        index < pointers.length;
        index++) {
      final Map<String, dynamic> pointer =
          pointers[index];

      final int? pointerId =
          _toInt(
        pointer['pointerId'],
      );

      if (pointerId == null) {
        continue;
      }

      if (!_capturedAndroidPointers
          .contains(pointerId)) {
        continue;
      }

      final double? x =
          _toDouble(
        pointer['x'],
      );

      final double? y =
          _toDouble(
        pointer['y'],
      );

      final double? pressure =
          _toDouble(
        pointer['pressure'],
      );

      final double? size =
          _toDouble(
        pointer['size'],
      );

      final double? touchMajor =
          _toDouble(
        pointer['touchMajor'],
      );

      final double? touchMinor =
          _toDouble(
        pointer['touchMinor'],
      );

      final double? toolMajor =
          _toDouble(
        pointer['toolMajor'],
      );

      final double? toolMinor =
          _toDouble(
        pointer['toolMinor'],
      );

      final TouchEventRecord record =
          TouchEventRecord(
        source: 'ANDROID',
        eventType: actionName,
        timestamp: timestamp,
        pointerIndex: index,
        pointerId: pointerId,
        pointerCount:
            _capturedAndroidPointers.length,
        x: x,
        y: y,
        deltaX: null,
        deltaY: null,
        pressure: pressure,
        size: size,
        touchMajor: touchMajor,
        touchMinor: touchMinor,
        toolMajor: toolMajor,
        toolMinor: toolMinor,
      );

      _recorder.add(record);

      if (pointerId == actionPointerId) {
        _updateCurrentState(
          source: record.source,
          eventType: record.eventType,
          pointerId: record.pointerId,
          pointerCount:
              record.pointerCount,
          x: record.x,
          y: record.y,
          pressure: record.pressure,
          size: record.size,
        );

        updatedDisplay = true;
      }
    }

    // -------------------------------------------------------------------------
    // CANCEL
    // -------------------------------------------------------------------------

    if (!updatedDisplay &&
        actionName == 'CANCEL') {
      Map<String, dynamic>? firstCaptured;

      for (final pointer in pointers) {
        final int? pointerId =
            _toInt(
          pointer['pointerId'],
        );

        if (pointerId != null &&
            _capturedAndroidPointers
                .contains(pointerId)) {
          firstCaptured = pointer;
          break;
        }
      }

      if (firstCaptured != null) {
        _updateCurrentState(
          source: 'ANDROID',
          eventType: 'CANCEL',
          pointerId:
              _toInt(
                    firstCaptured['pointerId'],
                  ) ??
                  -1,
          pointerCount:
              _capturedAndroidPointers.length,
          x: _toDouble(
            firstCaptured['x'],
          ),
          y: _toDouble(
            firstCaptured['y'],
          ),
          pressure: _toDouble(
            firstCaptured['pressure'],
          ),
          size: _toDouble(
            firstCaptured['size'],
          ),
        );
      }
    }

    _updateSessionCounts();

    // -------------------------------------------------------------------------
    // REMOVE PONTEIRO LIBERADO
    // -------------------------------------------------------------------------

    if (actionName == 'POINTER_UP') {
      if (actionPointerId != null) {
        _capturedAndroidPointers.remove(
          actionPointerId,
        );
      }
    }

    if (actionName == 'UP' ||
        actionName == 'CANCEL') {
      _capturedAndroidPointers.clear();
    }

    if (mounted) {
      setState(() {});
    }
  }

  bool _shouldProcessAndroidAction(
    String actionName,
  ) {
    const Set<String> validActions = {
      'DOWN',
      'POINTER_DOWN',
      'MOVE',
      'POINTER_UP',
      'UP',
      'CANCEL',
    };

    return validActions.contains(
      actionName,
    );
  }

  // ===========================================================================
  // COORDENADAS ANDROID
  // ===========================================================================

  bool _isAndroidPointInsideTouchArea(
    double xPhysical,
    double yPhysical,
  ) {
    final RenderBox? renderBox =
        _touchAreaKey.currentContext
            ?.findRenderObject() as RenderBox?;

    if (renderBox == null) {
      return false;
    }

    final double devicePixelRatio =
        View.of(context).devicePixelRatio;

    final Offset logicalPoint = Offset(
      xPhysical / devicePixelRatio,
      yPhysical / devicePixelRatio,
    );

    final Offset globalOrigin =
        renderBox.localToGlobal(
      Offset.zero,
    );

    final Rect globalRect =
        globalOrigin & renderBox.size;

    return globalRect.contains(
      logicalPoint,
    );
  }

  // ===========================================================================
  // ATUALIZA ESTADO VISUAL
  // ===========================================================================

  void _updateCurrentState({
    required String source,
    required String eventType,
    required int pointerId,
    required int pointerCount,
    double? x,
    double? y,
    double? pressure,
    double? size,
  }) {
    if (!mounted) {
      return;
    }

    setState(() {
      _lastSource = source;
      _lastEventType = eventType;
      _lastPointerId = pointerId;
      _lastPointerCount = pointerCount;
      _lastX = x;
      _lastY = y;
      _lastPressure = pressure;
      _lastSize = size;

      // MOVE não substitui a última transição.
      if (eventType != 'MOVE') {
        _lastTransitionSource = source;
        _lastTransitionType = eventType;
      }

      _eventTypeCounts[eventType] =
          (_eventTypeCounts[eventType] ?? 0) + 1;

      final String shortSource =
          source == 'ANDROID'
              ? 'A'
              : 'F';

      _eventSequence.add(
        '$shortSource:$eventType',
      );

      if (_eventSequence.length > 12) {
        _eventSequence.removeAt(0);
      }
    });
  }

  void _updateSessionCounts() {
    if (_sessionManager.isCollecting) {
      _sessionManager.updateCounts(
        _recorder,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _displayedFlutterEvents =
          _recorder.flutterEvents;

      _displayedAndroidEvents =
          _recorder.androidEvents;
    });
  }

  // ===========================================================================
  // SESSÃO
  // ===========================================================================

  Future<void> _toggleCollection() async {
  // -------------------------------------------------------------------------
  // INICIAR
  // -------------------------------------------------------------------------

  if (!_sessionManager.isCollecting) {
    _activeFlutterPointers.clear();
    _capturedAndroidPointers.clear();
    _recorder.clear();

    // Caracteriza o aparelho no início da sessão.
    _deviceCharacterization =
        await _deviceCharacterizationService.collect(
      context,
    );

    _eventTypeCounts.updateAll(
      (key, value) => 0,
    );

    _eventSequence.clear();

    _sessionManager.start(
      _recorder,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _displayedFlutterEvents = 0;
      _displayedAndroidEvents = 0;

      _lastSource = '-';
      _lastEventType = '-';

      _lastTransitionSource = '-';
      _lastTransitionType = '-';

      _lastPointerId = null;
      _lastPointerCount = 0;

      _lastX = null;
      _lastY = null;

      _lastPressure = null;
      _lastSize = null;
    });

    return;
  }

  // -------------------------------------------------------------------------
  // FINALIZAR
  // -------------------------------------------------------------------------

  final CollectionSession? session =
      _sessionManager.finish(
    _recorder,
  );

  if (session == null) {
    return;
  }

  final List<TouchEventRecord> eventsSnapshot =
      List<TouchEventRecord>.from(
    _recorder.events,
  );

  final TouchAnalysisResult flutterAnalysis =
      _analysisService.analyze(
    source: 'FLUTTER',
    events: eventsSnapshot,
  );

  final TouchAnalysisResult androidAnalysis =
      _analysisService.analyze(
    source: 'ANDROID',
    events: eventsSnapshot,
  );

  // -------------------------------------------------------------------------
  // GERAR CSV EM MEMÓRIA
  // -------------------------------------------------------------------------

  final String csvContent =
      _csvService.buildSessionCsv(
    session: session,
    events: eventsSnapshot,
    device: _deviceCharacterization,
  );

  if (!mounted) {
    return;
  }

  // -------------------------------------------------------------------------
  // MOSTRAR RESUMO
  //
  // O CSV NÃO é salvo automaticamente.
  // O usuário decidirá depois entre:
  //   - ABRIR COM
  //   - COMPARTILHAR
  // -------------------------------------------------------------------------

  await _showSessionSummary(
    session,
    flutterAnalysis,
    androidAnalysis,
    csvContent,
  );
}

  // ===========================================================================
  // RESUMO DA SESSÃO
  // ===========================================================================

  Future<void> _showSessionSummary(
  CollectionSession session,
  TouchAnalysisResult flutterAnalysis,
  TouchAnalysisResult androidAnalysis,
  String csvContent,
) async {
  final Duration? duration = session.duration;

  final String fileName =
      'touch_session_${session.id}.csv';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text(
          'Coleta finalizada',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Sessão:',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              Text(session.id),

              const SizedBox(
                height: 12,
              ),

              Text(
                'Duração: '
                '${duration?.inMilliseconds ?? 0} ms',
              ),

              Text(
                'Flutter: '
                '${session.flutterEvents} eventos',
              ),

              Text(
                'Android: '
                '${session.androidEvents} eventos',
              ),

              const SizedBox(
                height: 16,
              ),

              // ==========================================================
              // ANÁLISE FLUTTER
              // ==========================================================

              const Text(
                'Análise temporal — Flutter',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                'Registros: '
                '${flutterAnalysis.totalRecords}',
              ),

              Text(
                'Eventos/timestamps únicos: '
                '${flutterAnalysis.uniqueEvents}',
              ),

              Text(
                'Intervalos analisados: '
                '${flutterAnalysis.intervalCount}',
              ),

              Text(
                'Δt médio: '
                '${_formatAnalysisValue(
                  flutterAnalysis.meanDeltaMs,
                )} ms',
              ),

              Text(
                'Δt mediano: '
                '${_formatAnalysisValue(
                  flutterAnalysis.medianDeltaMs,
                )} ms',
              ),

              Text(
                'Desvio-padrão: '
                '${_formatAnalysisValue(
                  flutterAnalysis.standardDeviationMs,
                )} ms',
              ),

              Text(
                'Mínimo: '
                '${_formatAnalysisValue(
                  flutterAnalysis.minDeltaMs,
                )} ms',
              ),

              Text(
                'Máximo: '
                '${_formatAnalysisValue(
                  flutterAnalysis.maxDeltaMs,
                )} ms',
              ),

              Text(
                'P5: '
                '${_formatAnalysisValue(
                  flutterAnalysis.percentile5Ms,
                )} ms',
              ),

              Text(
                'P95: '
                '${_formatAnalysisValue(
                  flutterAnalysis.percentile95Ms,
                )} ms',
              ),

              Text(
                'Frequência observada: '
                '${_formatAnalysisValue(
                  flutterAnalysis.observedRateHz,
                )} Hz',
              ),

              Text(
                'MOVE: '
                '${flutterAnalysis.moveEventCount} eventos',
              ),

              Text(
                'MOVE Δt mediano: '
                '${_formatAnalysisValue(
                  flutterAnalysis.moveMedianDeltaMs,
                )} ms',
              ),

              Text(
                'MOVE frequência observada: '
                '${_formatAnalysisValue(
                  flutterAnalysis.moveObservedRateHz,
                )} Hz',
              ),

              const SizedBox(
                height: 16,
              ),

              // ==========================================================
              // ANÁLISE ANDROID
              // ==========================================================

              const Text(
                'Análise temporal — Android',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                'Registros: '
                '${androidAnalysis.totalRecords}',
              ),

              Text(
                'Eventos/timestamps únicos: '
                '${androidAnalysis.uniqueEvents}',
              ),

              Text(
                'Intervalos analisados: '
                '${androidAnalysis.intervalCount}',
              ),

              Text(
                'Δt médio: '
                '${_formatAnalysisValue(
                  androidAnalysis.meanDeltaMs,
                )} ms',
              ),

              Text(
                'Δt mediano: '
                '${_formatAnalysisValue(
                  androidAnalysis.medianDeltaMs,
                )} ms',
              ),

              Text(
                'Desvio-padrão: '
                '${_formatAnalysisValue(
                  androidAnalysis.standardDeviationMs,
                )} ms',
              ),

              Text(
                'Mínimo: '
                '${_formatAnalysisValue(
                  androidAnalysis.minDeltaMs,
                )} ms',
              ),

              Text(
                'Máximo: '
                '${_formatAnalysisValue(
                  androidAnalysis.maxDeltaMs,
                )} ms',
              ),

              Text(
                'P5: '
                '${_formatAnalysisValue(
                  androidAnalysis.percentile5Ms,
                )} ms',
              ),

              Text(
                'P95: '
                '${_formatAnalysisValue(
                  androidAnalysis.percentile95Ms,
                )} ms',
              ),

              Text(
                'Frequência observada: '
                '${_formatAnalysisValue(
                  androidAnalysis.observedRateHz,
                )} Hz',
              ),

              Text(
                'MOVE: '
                '${androidAnalysis.moveEventCount} eventos',
              ),

              Text(
                'MOVE Δt mediano: '
                '${_formatAnalysisValue(
                  androidAnalysis.moveMedianDeltaMs,
                )} ms',
              ),

              Text(
                'MOVE frequência observada: '
                '${_formatAnalysisValue(
                  androidAnalysis.moveObservedRateHz,
                )} Hz',
              ),

              const SizedBox(
                height: 16,
              ),

              // ==========================================================
              // CSV
              // ==========================================================

              const Text(
                'Arquivo CSV:',
                style: TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                fileName,
                style: const TextStyle(
                  fontSize: 13,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              const Text(
                'O CSV não é salvo automaticamente. '
                'Escolha uma das opções abaixo.',
                style: TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // ================================================================
        // BOTÕES
        // ================================================================

        actions: [
          TextButton.icon(
            onPressed: () async {
              Navigator.of(
                dialogContext,
              ).pop();

              try {
                await _csvService.openCsv(
                  fileName: fileName,
                  content: csvContent,
                );
              } catch (error) {
                if (!mounted) {
                  return;
                }

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Erro ao abrir o CSV: $error',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(
              Icons.open_in_new,
            ),
            label: const Text(
              'ABRIR COM',
            ),
          ),

          TextButton.icon(
            onPressed: () async {
              Navigator.of(
                dialogContext,
              ).pop();

              try {
                await _csvService.shareCsv(
                  fileName: fileName,
                  content: csvContent,
                );
              } catch (error) {
                if (!mounted) {
                  return;
                }

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Erro ao compartilhar CSV: $error',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(
              Icons.share,
            ),
            label: const Text(
              'COMPARTILHAR',
            ),
          ),

          TextButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop();
            },
            child: const Text(
              'OK',
            ),
          ),
        ],
      );
    },
  );
}

  String _formatAnalysisValue(
    double? value,
  ) {
    if (value == null) {
      return 'n/a';
    }

    return value.toStringAsFixed(2);
  }

  // ===========================================================================
  // MARCADORES DOS DEDOS
  // ===========================================================================

  List<Widget> _buildPointerMarkers() {
    const List<Color> pointerColors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
      Colors.pink,
      Colors.cyan,
    ];

    final List<Widget> markers = [];

    for (final entry
        in _activeFlutterPointers.entries) {
      final int pointerId = entry.key;
      final Offset position = entry.value;

      final Color color =
          pointerColors[
            pointerId % pointerColors.length
          ];

      markers.add(
        Positioned(
          left: position.dx - 28,
          top: position.dy - 28,
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$pointerId',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(6),
                    border: Border.all(
                      color: color,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'ID $pointerId',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  // ===========================================================================
  // ESTADOS ATUAIS
  // ===========================================================================

  String _activeFlutterText() {
    if (_activeFlutterPointers.isEmpty) {
      return 'nenhum';
    }

    final List<int> ids =
        _activeFlutterPointers.keys.toList()
          ..sort();

    return ids.join(', ');
  }

  String _activeAndroidText() {
    if (_capturedAndroidPointers.isEmpty) {
      return 'nenhum';
    }

    final List<int> ids =
        _capturedAndroidPointers.toList()
          ..sort();

    return ids.join(', ');
  }

  // ===========================================================================
  // CORES / ÍCONES
  // ===========================================================================

  Color _eventColor(
    String eventType,
  ) {
    switch (eventType) {
      case 'DOWN':
        return Colors.green;

      case 'POINTER_DOWN':
        return Colors.blue;

      case 'POINTER_UP':
        return Colors.orange;

      case 'UP':
        return Colors.purple;

      case 'CANCEL':
        return Colors.red;

      case 'MOVE':
        return Colors.grey;

      default:
        return Colors.grey;
    }
  }

  IconData _eventIcon(
    String eventType,
  ) {
    switch (eventType) {
      case 'DOWN':
        return Icons.touch_app;

      case 'POINTER_DOWN':
        return Icons.add_circle;

      case 'POINTER_UP':
        return Icons.remove_circle;

      case 'UP':
        return Icons.pan_tool;

      case 'CANCEL':
        return Icons.cancel;

      case 'MOVE':
        return Icons.open_with;

      default:
        return Icons.touch_app;
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool isCollecting =
        _sessionManager.isCollecting;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Touchscreen',
        ),
      ),
      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            // =================================================================
            // BOTÃO
            // =================================================================

            ElevatedButton.icon(
              onPressed:
                  _toggleCollection,
              icon: Icon(
                isCollecting
                    ? Icons.stop
                    : Icons.play_arrow,
              ),
              label: Text(
                isCollecting
                    ? 'FINALIZAR COLETA'
                    : 'INICIAR COLETA',
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            // =================================================================
            // STATUS
            // =================================================================

            Container(
              padding:
                  const EdgeInsets.all(14),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isCollecting
                        ? Icons.circle
                        : Icons.circle_outlined,
                    size: 15,
                  ),
                  const SizedBox(
                    width: 8,
                  ),
                  Text(
                    isCollecting
                        ? 'COLETA EM ANDAMENTO'
                        : 'COLETA PARADA',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // =================================================================
            // CONTADORES FLUTTER / ANDROID
            // =================================================================

            Row(
              children: [
                Expanded(
                  child:
                      _CounterCard(
                    title: 'FLUTTER',
                    value:
                        '$_displayedFlutterEvents',
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child:
                      _CounterCard(
                    title: 'ANDROID',
                    value:
                        '$_displayedAndroidEvents',
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            // =================================================================
            // EVENTOS CAPTURADOS
            // =================================================================

            const Text(
              'Eventos capturados',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _EventCountCard(
                  title: 'DOWN',
                  value:
                      _eventTypeCounts[
                              'DOWN'] ??
                          0,
                  color:
                      Colors.green,
                ),

                _EventCountCard(
                  title:
                      'POINTER_DOWN',
                  value:
                      _eventTypeCounts[
                              'POINTER_DOWN'] ??
                          0,
                  color:
                      Colors.blue,
                ),

                _EventCountCard(
                  title:
                      'POINTER_UP',
                  value:
                      _eventTypeCounts[
                              'POINTER_UP'] ??
                          0,
                  color:
                      Colors.orange,
                ),

                _EventCountCard(
                  title: 'UP',
                  value:
                      _eventTypeCounts[
                              'UP'] ??
                          0,
                  color:
                      Colors.purple,
                ),

                _EventCountCard(
                  title: 'CANCEL',
                  value:
                      _eventTypeCounts[
                              'CANCEL'] ??
                          0,
                  color:
                      Colors.red,
                ),

                _EventCountCard(
                  title: 'MOVE',
                  value:
                      _eventTypeCounts[
                              'MOVE'] ??
                          0,
                  color:
                      Colors.grey,
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            // =================================================================
            // ESTADO ATUAL
            // =================================================================

            _SectionCard(
              title:
                  'Estado atual',
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Flutter ativos: '
                    '${_activeFlutterPointers.length}',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  Text(
                    'IDs Flutter: '
                    '${_activeFlutterText()}',
                  ),

                  const SizedBox(
                    height: 8,
                  ),

                  Text(
                    'Android ativos: '
                    '${_capturedAndroidPointers.length}',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  Text(
                    'IDs Android: '
                    '${_activeAndroidText()}',
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // =================================================================
            // ÚLTIMA TRANSIÇÃO
            // =================================================================

            _TransitionCard(
              source:
                  _lastTransitionSource,
              eventType:
                  _lastTransitionType,
            ),

            const SizedBox(
              height: 8,
            ),

            // =================================================================
            // ÚLTIMO EVENTO RAW
            // =================================================================

            _LastEventCard(
              source: _lastSource,
              eventType: _lastEventType,
              pointerId:
                  _lastPointerId,
              pointerCount:
                  _lastPointerCount,
              x: _lastX,
              y: _lastY,
              pressure:
                  _lastPressure,
              size:
                  _lastSize,
              color:
                  _eventColor(
                _lastEventType,
              ),
              icon:
                  _eventIcon(
                _lastEventType,
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // =================================================================
            // SEQUÊNCIA
            // =================================================================

            const Text(
              'Sequência recente',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(
              height: 8,
            ),

            Container(
              padding:
                  const EdgeInsets.all(10),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey,
                ),
              ),
              child:
                  _eventSequence.isEmpty
                      ? const Text(
                          'Nenhum evento ainda.',
                        )
                      : SingleChildScrollView(
                          scrollDirection:
                              Axis.horizontal,
                          child: Row(
                            children:
                                _eventSequence.map(
                              (item) {
                                final List<String>
                                    parts =
                                    item.split(':');

                                final String type =
                                    parts.length >
                                            1
                                        ? parts[1]
                                        : item;

                                return Padding(
                                  padding:
                                      const EdgeInsets
                                          .only(
                                    right: 6,
                                  ),
                                  child:
                                      Chip(
                                    avatar:
                                        CircleAvatar(
                                      child:
                                          Text(
                                        parts[0],
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              9,
                                        ),
                                      ),
                                    ),
                                    label:
                                        Text(
                                      type,
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            11,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ).toList(),
                          ),
                        ),
            ),

            const SizedBox(
              height: 20,
            ),

            // =================================================================
            // ÁREA DE TOQUE
            // =================================================================

            const Text(
              'Área de toque',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 20,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Container(
              key: _touchAreaKey,
              height: 390,
              width: double.infinity,
              clipBehavior:
                  Clip.hardEdge,
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(14),
                border: Border.all(
                  width: 3,
                  color:
                      _lastEventType ==
                              'CANCEL'
                          ? Colors.red
                          : Colors.grey,
                ),
              ),
              child: Listener(
                behavior:
                    HitTestBehavior.opaque,
                onPointerDown:
                    _onPointerDown,
                onPointerMove:
                    _onPointerMove,
                onPointerUp:
                    _onPointerUp,
                onPointerCancel:
                    _onPointerCancel,
                child: Stack(
                  fit:
                      StackFit.expand,
                  children: [
                    // ---------------------------------------------------------
                    // ESTADO FLUTTER / ANDROID
                    // ---------------------------------------------------------

                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                          border:
                              Border.all(
                            color: Colors.grey,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'FLUTTER ATIVOS',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),

                            Text(
                              '${_activeFlutterPointers.length}',
                              style:
                                  const TextStyle(
                                fontSize: 24,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            Text(
                              'IDs: '
                              '${_activeFlutterText()}',
                              style:
                                  const TextStyle(
                                fontSize: 11,
                              ),
                            ),

                            const SizedBox(
                              height: 6,
                            ),

                            const Text(
                              'ANDROID ATIVOS',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),

                            Text(
                              '${_capturedAndroidPointers.length}',
                              style:
                                  const TextStyle(
                                fontSize: 18,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            Text(
                              'IDs: '
                              '${_activeAndroidText()}',
                              style:
                                  const TextStyle(
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ---------------------------------------------------------
                    // TEXTO CENTRAL
                    // ---------------------------------------------------------

                    Center(
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          const Text(
                            'TOQUE AQUI',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          Text(
                            'Flutter: '
                            '${_activeFlutterPointers.length}',
                            style:
                                const TextStyle(
                              fontSize: 16,
                            ),
                          ),

                          Text(
                            'Android: '
                            '${_capturedAndroidPointers.length}',
                            style:
                                const TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ---------------------------------------------------------
                    // MARCADORES
                    // ---------------------------------------------------------

                    ..._buildPointerMarkers(),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            // =================================================================
            // DESCRIÇÃO
            // =================================================================

            const Text(
              'Área experimental de toque',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            const Text(
              'Toques iniciados nesta área '
              'são utilizados na coleta.',
            ),

            const SizedBox(
              height: 20,
            ),

            // =================================================================
            // LOG TÉCNICO
            // =================================================================

            ExpansionTile(
              title:
                  const Text(
                'Eventos recentes detalhados',
                style:
                    TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              subtitle:
                  Text(
                '${_recorder.events.length} '
                'registros armazenados',
              ),
              children: [
                if (_recorder.events.isEmpty)
                  const Padding(
                    padding:
                        EdgeInsets.all(16),
                    child: Text(
                      'Nenhum evento registrado.',
                    ),
                  )
                else
                  ..._recorder
                      .recentEvents(
                    limit: 20,
                  )
                      .reversed
                      .map(
                    (event) {
                      return _EventTile(
                        event: event,
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// CARD FLUTTER / ANDROID
// =============================================================================

class _CounterCard
    extends StatelessWidget {
  final String title;
  final String value;

  const _CounterCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              value,
              style:
                  const TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// CONTADOR DE EVENTOS
// =============================================================================

class _EventCountCard
    extends StatelessWidget {
  final String title;
  final int value;
  final Color color;

  const _EventCountCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 140,
      padding:
          const EdgeInsets.all(10),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
              fontSize: 11,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            '$value',
            style:
                const TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CARD DE SEÇÃO
// =============================================================================

class _SectionCard
    extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding:
            const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 17,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            child,
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ÚLTIMA TRANSIÇÃO
// =============================================================================

class _TransitionCard
    extends StatelessWidget {
  final String source;
  final String eventType;

  const _TransitionCard({
    required this.source,
    required this.eventType,
  });

  Color _color() {
    switch (eventType) {
      case 'DOWN':
        return Colors.green;

      case 'POINTER_DOWN':
        return Colors.blue;

      case 'POINTER_UP':
        return Colors.orange;

      case 'UP':
        return Colors.purple;

      case 'CANCEL':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final Color color = _color();

    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.swap_horiz,
            color: color,
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'ÚLTIMA TRANSIÇÃO',
                  style:
                      TextStyle(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                Text(
                  eventType,
                  style:
                      TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                    color: color,
                  ),
                ),

                Text(
                  'Fonte: $source',
                  style:
                      const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ÚLTIMO EVENTO RAW
// =============================================================================

class _LastEventCard
    extends StatelessWidget {
  final String source;
  final String eventType;
  final int? pointerId;
  final int pointerCount;
  final double? x;
  final double? y;
  final double? pressure;
  final double? size;
  final Color color;
  final IconData icon;

  const _LastEventCard({
    required this.source,
    required this.eventType,
    required this.pointerId,
    required this.pointerCount,
    required this.x,
    required this.y,
    required this.pressure,
    required this.size,
    required this.color,
    required this.icon,
  });

  String _format(
    double? value,
  ) {
    if (value == null) {
      return 'n/a';
    }

    return value.toStringAsFixed(3);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool isCancel =
        eventType == 'CANCEL';

    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color: color,
          width: 3,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 30,
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: Text(
                  eventType,
                  style:
                      TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'Fonte: $source',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          Text(
            'Ponteiro: '
            '${pointerId ?? 'n/a'}',
          ),

          Text(
            'Ponteiros neste evento: '
            '$pointerCount',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          Text(
            'X: ${_format(x)}   '
            'Y: ${_format(y)}',
          ),

          Text(
            'Pressão: '
            '${_format(pressure)}',
          ),

          Text(
            'Tamanho: '
            '${_format(size)}',
          ),

          if (isCancel) ...[
            const SizedBox(
              height: 8,
            ),
            const Text(
              '⚠ CANCEL: sequência de toque encerrada.',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// EVENTO DETALHADO
// =============================================================================

class _EventTile
    extends StatelessWidget {
  final TouchEventRecord event;

  const _EventTile({
    required this.event,
  });

  String _formatDouble(
    double? value,
  ) {
    if (value == null) {
      return 'n/a';
    }

    return value.toStringAsFixed(3);
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: 6,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${event.source} / '
                    '${event.eventType}',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  'ID ${event.pointerId}',
                  style:
                      const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              'timestamp: '
              '${event.timestamp}',
              style:
                  const TextStyle(
                fontSize: 12,
              ),
            ),

            Text(
              'pointerIndex: '
              '${event.pointerIndex}   '
              'pointerCount: '
              '${event.pointerCount}',
              style:
                  const TextStyle(
                fontSize: 12,
              ),
            ),

            Text(
              'X: '
              '${_formatDouble(event.x)}   '
              'Y: '
              '${_formatDouble(event.y)}',
              style:
                  const TextStyle(
                fontSize: 12,
              ),
            ),

            Text(
              'ΔX: '
              '${_formatDouble(event.deltaX)}   '
              'ΔY: '
              '${_formatDouble(event.deltaY)}',
              style:
                  const TextStyle(
                fontSize: 12,
              ),
            ),

            Text(
              'pressure: '
              '${_formatDouble(event.pressure)}   '
              'size: '
              '${_formatDouble(event.size)}',
              style:
                  const TextStyle(
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}