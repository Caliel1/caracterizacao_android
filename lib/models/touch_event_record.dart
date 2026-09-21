class TouchEventRecord {
  final String source;
  final String eventType;

  final int timestamp;

  // Posição do ponteiro dentro da lista do evento.
  final int pointerIndex;

  // ID real do ponteiro.
  final int pointerId;

  // Número de ponteiros presentes no MotionEvent.
  final int pointerCount;

  final double? x;
  final double? y;

  final double? deltaX;
  final double? deltaY;

  final double? pressure;
  final double? size;

  final double? touchMajor;
  final double? touchMinor;

  final double? toolMajor;
  final double? toolMinor;

  TouchEventRecord({
    required this.source,
    required this.eventType,
    required this.timestamp,
    required this.pointerIndex,
    required this.pointerId,
    required this.pointerCount,
    this.x,
    this.y,
    this.deltaX,
    this.deltaY,
    this.pressure,
    this.size,
    this.touchMajor,
    this.touchMinor,
    this.toolMajor,
    this.toolMinor,
  });

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'event_type': eventType,
      'timestamp': timestamp,
      'pointer_index': pointerIndex,
      'pointer_id': pointerId,
      'pointer_count': pointerCount,
      'x': x,
      'y': y,
      'delta_x': deltaX,
      'delta_y': deltaY,
      'pressure': pressure,
      'size': size,
      'touch_major': touchMajor,
      'touch_minor': touchMinor,
      'tool_major': toolMajor,
      'tool_minor': toolMinor,
    };
  }
}