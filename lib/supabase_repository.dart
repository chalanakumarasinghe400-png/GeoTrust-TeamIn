import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'db_repository.dart';

class SupabaseRepository implements DbRepository {
  final _client = Supabase.instance.client;

  Map<String, Object> _toObjectMap(Map<String, dynamic> map) {
    return map.map((k, v) => MapEntry(k, v as Object));
  }

  @override
  Stream<List<Map<String, dynamic>>> streamTable(
    String table, {
    required String primaryKey,
    Map<String, dynamic>? eq,
  }) {
    final query = _client.from(table).stream(primaryKey: [primaryKey]);
    if (eq != null) {
      eq.forEach((k, v) {
        query.eq(k, v);
      });
    }
    return query.map((list) => List<Map<String, dynamic>>.from(list));
  }

  @override
  Future<Map<String, dynamic>?> selectOne(
    String table,
    String column,
    dynamic value, {
    List<String>? columns,
  }) async {
    var sel = columns?.join(',');
    final res = await _client
        .from(table)
        .select(sel ?? '*')
        .eq(column, value)
        .maybeSingle();
    return res == null ? null : Map<String, dynamic>.from(res as Map);
  }

  @override
  Future<List<Map<String, dynamic>>> select(
    String table, {
    Map<String, dynamic>? filters,
  }) async {
    var query = _client.from(table).select();
    if (filters != null && filters.isNotEmpty) {
      query = query.match(_toObjectMap(filters));
    }
    final res = await query;
    return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<Map<String, dynamic>?> selectWhereSingle(
    String table,
    Map<String, dynamic> filters,
  ) async {
    final res = await _client.from(table).select().match(_toObjectMap(filters)).maybeSingle();
    return res == null ? null : Map<String, dynamic>.from(res as Map);
  }

  @override
  Future<void> insert(String table, Map<String, dynamic> payload) async {
    await _client.from(table).insert(payload);
  }

  @override
  Future<void> update(
    String table,
    Map<String, dynamic> payload, {
    required String eqColumn,
    required dynamic eqValue,
  }) async {
    await _client.from(table).update(payload).eq(eqColumn, eqValue);
  }

  @override
  Future<void> uploadBinary(
    String bucket,
    String path,
    List<int> bytes, {
    String? contentType,
  }) async {
    final fileOptions = FileOptions(contentType: contentType ?? 'application/octet-stream');
    // Supabase storage expects Uint8List
    await _client.storage.from(bucket).uploadBinary(path, Uint8List.fromList(bytes), fileOptions: fileOptions);
  }

  @override
  String getPublicUrl(String bucket, String path) {
    return _client.storage.from(bucket).getPublicUrl(path);
  }

  @override
  Future<List<Map<String, dynamic>>> getPermitsByOriginIdsAndStatus(
    List<String> originIds,
    String status,
  ) async {
    if (originIds.isEmpty) return [];
    final orString = originIds.map((id) => 'origin_location_id.eq.$id').join(',');
    final res = await _client.from('permits').select().or(orString).eq('status', status);
    return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getLocationsByType(String type) async {
    final res = await _client.from('locations').select().eq('location_type', type);
    return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
