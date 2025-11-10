import 'package:isar_community/isar.dart';

part 'cached_ttl_etag_response.g.dart';

@collection
class CachedTtlEtagResponse<T> {
  Id id = Isar.autoIncrement;

  /// Clé unique pour GET ou POST
  @Index(unique: true) // ✅ This ensures only ONE entry per URL
  late String url;

  late String data;

  String? etag;

  late DateTime timestamp;

  late int ttlSeconds;

  bool isStale = false;
}
