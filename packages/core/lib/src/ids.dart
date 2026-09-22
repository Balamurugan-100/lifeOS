import 'package:uuid/uuid.dart';

const Uuid _uuid = Uuid();

/// Generates a collision-safe UUID (v4) string id for any LifeOS entity.
///
/// UUIDs are required by the data model so future multi-device sync never
/// collides (data-model.md conventions).
String newId() => _uuid.v4();

/// Returns true when [id] looks like a well-formed UUID (v4) string.
bool isValidId(String id) {
  final match = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  return match.hasMatch(id);
}