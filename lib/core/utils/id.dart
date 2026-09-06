import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// New v4 uuid for entity ids.
String newUuid() => _uuid.v4();
