import 'dart:convert';

/// Plain-text preview of a stored Quill delta JSON ({"ops":[...]} or [...]).
String deltaToPlainText(String deltaJson) {
  if (deltaJson.trim().isEmpty) return '';
  final decoded = jsonDecode(deltaJson);
  final ops = decoded is Map
      ? (decoded['ops'] as List? ?? const [])
      : decoded as List;
  final buffer = StringBuffer();
  for (final op in ops) {
    if (op is Map && op['insert'] is String) buffer.write(op['insert']);
  }
  return buffer.toString().trim();
}
