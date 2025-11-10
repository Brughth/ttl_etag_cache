/// Represents the state of a cached resource with all necessary UI metadata
///
/// This immutable state class contains all information needed by the UI layer
/// to properly render data, loading states, errors, and cache metadata.
class CacheTtlEtagState<T> {
  /// The cached data of type T, null if not yet loaded
  final T? data;

  /// Whether a fetch operation is currently in progress
  final bool isLoading;

  /// Whether the cached data has exceeded its TTL but is still being served
  final bool isStale;

  /// Any error that occurred during fetch or cache operations
  final Object? error;

  /// The timestamp when the data was last updated
  final DateTime? timestamp;

  /// Time-to-live in seconds for this cache entry
  final int? ttlSeconds;

  /// ETag value from the server for conditional requests
  final String? etag;

  const CacheTtlEtagState({
    this.data,
    this.isLoading = false,
    this.isStale = false,
    this.error,
    this.timestamp,
    this.ttlSeconds,
    this.etag,
  });

  /// Returns true if data is available
  bool get hasData => data != null;

  /// Returns true if an error has occurred
  bool get hasError => error != null;

  /// Returns true if the state is empty (no data, not loading, no error)
  bool get isEmpty => data == null && !isLoading && error == null;

  /// Returns true if cache has expired based on TTL
  bool get isExpired {
    if (timestamp == null || ttlSeconds == null) return false;
    final age = DateTime.now().difference(timestamp!).inSeconds;
    return age >= ttlSeconds!;
  }

  /// Returns remaining time until cache expires
  Duration? get timeUntilExpiry {
    if (timestamp == null || ttlSeconds == null) return null;
    final age = DateTime.now().difference(timestamp!).inSeconds;
    final remaining = ttlSeconds! - age;
    return remaining > 0 ? Duration(seconds: remaining) : Duration.zero;
  }

  /// Create a copy of this state with modified fields
  CacheTtlEtagState<T> copyWith({
    T? data,
    bool? isLoading,
    bool? isStale,
    Object? error,
    DateTime? timestamp,
    int? ttlSeconds,
    String? etag,
  }) {
    return CacheTtlEtagState<T>(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      isStale: isStale ?? this.isStale,
      error: error ?? this.error,
      timestamp: timestamp ?? this.timestamp,
      ttlSeconds: ttlSeconds ?? this.ttlSeconds,
      etag: etag ?? this.etag,
    );
  }

  @override
  String toString() {
    return 'CacheTtlEtagState(hasData: $hasData, isLoading: $isLoading, '
        'isStale: $isStale, hasError: $hasError, isExpired: $isExpired)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CacheTtlEtagState<T> &&
        other.data == data &&
        other.isLoading == isLoading &&
        other.isStale == isStale &&
        other.error == error &&
        other.timestamp == timestamp &&
        other.ttlSeconds == ttlSeconds &&
        other.etag == etag;
  }

  @override
  int get hashCode {
    return Object.hash(
      data,
      isLoading,
      isStale,
      error,
      timestamp,
      ttlSeconds,
      etag,
    );
  }
}
