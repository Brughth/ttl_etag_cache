class CacheTtlEtagState<T> {
  final T? data;
  final bool isLoading;
  final bool isStale;
  final Object? error;
  final DateTime? timestamp;
  final int? ttlSeconds;
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

  bool get hasData => data != null;
  bool get hasError => error != null;
  bool get isEmpty => data == null && !isLoading && error == null;

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
    return 'CacheTtlEtagState(hasData: $hasData, isLoading: $isLoading, isStale: $isStale, hasError: $hasError)';
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
