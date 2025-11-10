import 'package:isar_community/isar.dart';

part 'cached_ttl_etag_response.g.dart';

/// Isar collection model for cached HTTP responses with TTL and ETag support
///
/// This model stores cached HTTP responses with support for both plain and
/// encrypted data storage, TTL-based expiration, and ETag conditional requests.
@collection
class CachedTtlEtagResponse {
  /// Unique identifier (auto-incremented by Isar)
  Id id = Isar.autoIncrement;

  /// Cache key (URL or custom key) - indexed as unique
  ///
  /// This ensures only one cache entry exists per unique URL/key combination
  @Index(unique: true)
  late String url;

  /// Plain text data (used when encryption is disabled)
  String? data;

  /// Encrypted data (used when encryption is enabled)
  String? encryptedData;

  /// Initialization Vector for AES encryption
  String? iv;

  /// ETag value from the server for conditional requests
  String? etag;

  /// Timestamp when the cache entry was created or last updated
  late DateTime timestamp;

  /// Time-to-live in seconds
  late int ttlSeconds;

  /// Flag indicating if the cache has exceeded its TTL
  late bool isStale;

  /// Flag indicating if this entry is encrypted
  ///
  /// This allows the system to handle mixed plain/encrypted cache entries
  /// during encryption migration
  @Index()
  late bool isEncrypted;

  /// Computed property: cache age in seconds
  int get ageInSeconds => DateTime.now().difference(timestamp).inSeconds;

  /// Computed property: whether the cache has expired
  bool get isExpired => ageInSeconds >= ttlSeconds;

  /// Computed property: remaining TTL in seconds
  int get remainingTtl {
    final remaining = ttlSeconds - ageInSeconds;
    return remaining > 0 ? remaining : 0;
  }
}
