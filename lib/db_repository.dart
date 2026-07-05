import 'dart:async';

/// Database repository abstraction used by the app.
/// Implementations should return plain JSON-like Maps (String->dynamic) so
/// domain models (TransportPermit, AppUser) can be constructed with fromJson.
abstract class DbRepository {
  // Streams a table with an optional equality filter. The stream yields lists of rows.
  Stream<List<Map<String, dynamic>>> streamTable(
    String table, {
    required String primaryKey,
    Map<String, dynamic>? eq,
  });

  Future<Map<String, dynamic>?> selectOne(
    String table,
    String column,
    dynamic value, {
    List<String>? columns,
  });

  Future<List<Map<String, dynamic>>> select(
    String table, {
    Map<String, dynamic>? filters,
  });

  Future<Map<String, dynamic>?> selectWhereSingle(
    String table,
    Map<String, dynamic> filters,
  );

  Future<void> insert(String table, Map<String, dynamic> payload);

  Future<void> update(
    String table,
    Map<String, dynamic> payload, {
    required String eqColumn,
    required dynamic eqValue,
  });

  Future<void> uploadBinary(
    String bucket,
    String path,
    List<int> bytes, {
    String? contentType,
  });

  String getPublicUrl(String bucket, String path);

  Future<List<Map<String, dynamic>>> getPermitsByOriginIdsAndStatus(
    List<String> originIds,
    String status,
  );

  Future<List<Map<String, dynamic>>> getLocationsByType(String type);
}
