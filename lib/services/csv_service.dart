import 'package:flutter/services.dart';

import '../models/collection_session.dart';
import '../models/device_characterization.dart';
import '../models/touch_event_record.dart';

class CsvService {
  static const MethodChannel _channel =
      MethodChannel('caracterizacao_android/file_export');

  /// Separador de campos. O Excel em pt-BR usa ponto e vírgula por padrão,
  /// pois a vírgula é o separador decimal.
  static const String _separator = ';';

  /// Quebra de linha padrão do Windows/Excel.
  static const String _eol = '\r\n';

  /// BOM UTF-8: faz o Excel reconhecer a codificação e exibir acentos certos.
  static const String _utf8Bom = '\uFEFF';

  /// Colunas do CSV, na mesma ordem em que os valores são escritos em cada linha.
  static const List<String> _headers = [
    'session_id',
    'session_started_at',
    'session_ended_at',
    'session_duration_ms',
    'characterization_collected_at',
    'platform',
    'manufacturer',
    'brand',
    'model',
    'device',
    'product',
    'board',
    'hardware',
    'android_release',
    'android_sdk_int',
    'android_security_patch',
    'is_physical_device',
    'supported_32bit_abis',
    'supported_64bit_abis',
    'supported_abis',
    'display_physical_width_px',
    'display_physical_height_px',
    'device_pixel_ratio',
    'logical_width',
    'logical_height',
    'refresh_rate_hz',
    'display_id',
    'orientation',
    'app_name',
    'package_name',
    'app_version',
    'app_build_number',
    'source',
    'event_type',
    'timestamp_raw',
    'timestamp_unit',
    'timestamp_us',
    'coordinate_unit',
    'pointer_index',
    'pointer_id',
    'pointer_count',
    'x',
    'y',
    'delta_x',
    'delta_y',
    'pressure',
    'size',
    'touch_major',
    'touch_minor',
    'tool_major',
    'tool_minor',
  ];

  // ============================================================
  // GERA O CONTEÚDO DO CSV
  // ============================================================

  String buildSessionCsv({
    required CollectionSession session,
    required List<TouchEventRecord> events,
    DeviceCharacterization? device,
  }) {
    final StringBuffer buffer = StringBuffer();

    final Map<String, dynamic> deviceMap =
        device?.toMap() ?? <String, dynamic>{};

    // BOM (precisa ser o primeiro caractere do arquivo)
    buffer.write(_utf8Bom);

    // Cabeçalho
    buffer.write(_headers.join(_separator));
    buffer.write(_eol);

    // Dados dos eventos
    for (final event in events) {
      final String timestampUnit =
          event.source == 'FLUTTER' ? 'microseconds' : 'milliseconds';

      final int timestampUs =
          event.source == 'FLUTTER' ? event.timestamp : event.timestamp * 1000;

      final String coordinateUnit =
          event.source == 'FLUTTER' ? 'logical_px' : 'physical_px';

      final List<dynamic> row = [
        session.id,
        session.startedAt.toIso8601String(),
        session.endedAt?.toIso8601String() ?? '',
        session.duration?.inMilliseconds ?? '',

        // Caracterização do dispositivo
        deviceMap['characterization_collected_at'] ?? '',
        deviceMap['platform'] ?? '',
        deviceMap['manufacturer'] ?? '',
        deviceMap['brand'] ?? '',
        deviceMap['model'] ?? '',
        deviceMap['device'] ?? '',
        deviceMap['product'] ?? '',
        deviceMap['board'] ?? '',
        deviceMap['hardware'] ?? '',
        deviceMap['android_release'] ?? '',
        deviceMap['android_sdk_int'] ?? '',
        deviceMap['android_security_patch'] ?? '',
        deviceMap['is_physical_device'] ?? '',
        deviceMap['supported_32bit_abis'] ?? '',
        deviceMap['supported_64bit_abis'] ?? '',
        deviceMap['supported_abis'] ?? '',

        deviceMap['display_physical_width_px'] ?? '',
        deviceMap['display_physical_height_px'] ?? '',
        deviceMap['device_pixel_ratio'] ?? '',
        deviceMap['logical_width'] ?? '',
        deviceMap['logical_height'] ?? '',
        deviceMap['refresh_rate_hz'] ?? '',
        deviceMap['display_id'] ?? '',
        deviceMap['orientation'] ?? '',

        deviceMap['app_name'] ?? '',
        deviceMap['package_name'] ?? '',
        deviceMap['app_version'] ?? '',
        deviceMap['app_build_number'] ?? '',

        // Evento
        event.source,
        event.eventType,
        event.timestamp,
        timestampUnit,
        timestampUs,
        coordinateUnit,
        event.pointerIndex,
        event.pointerId,
        event.pointerCount,
        event.x,
        event.y,
        event.deltaX,
        event.deltaY,
        event.pressure,
        event.size,
        event.touchMajor,
        event.touchMinor,
        event.toolMajor,
        event.toolMinor,
      ];

      // Garante que cabeçalho e linhas têm o mesmo número de colunas
      // (só é verificado em modo debug).
      assert(
        row.length == _headers.length,
        'CSV: a linha tem ${row.length} colunas, mas o cabeçalho tem ${_headers.length}.',
      );

      buffer.write(row.map(_escapeCsv).join(_separator));
      buffer.write(_eol);
    }

    return buffer.toString();
  }

  // ============================================================
  // ABRIR CSV
  // ============================================================

  Future<void> openCsv({
    required String fileName,
    required String content,
  }) async {
    await _channel.invokeMethod(
      'openCsv',
      {
        'fileName': fileName,
        'content': content,
      },
    );
  }

  // ============================================================
  // COMPARTILHAR CSV
  // ============================================================

  Future<void> shareCsv({
    required String fileName,
    required String content,
  }) async {
    await _channel.invokeMethod(
      'shareCsv',
      {
        'fileName': fileName,
        'content': content,
      },
    );
  }

  // ============================================================
  // ESCAPE DOS CAMPOS CSV
  // ============================================================

  String _escapeCsv(dynamic value) {
    if (value == null) {
      return '';
    }

    String text = value.toString();

    // Excel pt-BR usa vírgula como separador decimal.
    // Para números (double), troca o ponto pela vírgula.
    if (value is double) {
      text = text.replaceAll('.', ',');
    }

    final bool needsQuotes = text.contains(_separator) ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r');

    if (!needsQuotes) {
      return text;
    }

    return '"${text.replaceAll('"', '""')}"';
  }
}