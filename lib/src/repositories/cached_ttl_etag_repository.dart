import 'dart:async';
import 'dart:convert';
import 'package:isar_community/isar.dart';
import 'package:rxdart/rxdart.dart';

import '../models/cached_ttl_etag_response.dart';
import '../models/cache_ttl_etag_state.dart';
import '../services/reactive_cache_dio.dart';

/// Repository pattern implementation for cached data access
///
/// This repository provides a reactive stream-based interface to cached data,
/// automatically handling encryption/decryption, TTL validation, and state updates.
///
/// Example:
/// ```dart
/// final userRepo = CachedTtlEtagRepository<User>(
///   url: 'https://api.example.com/user/123',
///   fromJson: (json) => User.fromJson(json),
///   defaultTtl: Duration(minutes: 5),
/// );
///
/// // Listen to state changes
/// userRepo.stream.listen((state) {
///   if (state.hasData) {
///     print('User: ${state.data!.name}');
///   }
/// });
///
/// // Fetch data
/// await userRepo.fetch();
///
/// // Dispose when done
/// userRepo.dispose();
/// ```
class CachedTtlEtagRepository<T> {
  final ReactiveCacheDio _cache;
  final String url;
  final Map<String, dynamic>? body;
  final String method;
  final Map<String, String>? headers;
  final Duration? defaultTtl;
  final T Function(dynamic) fromJson;
  final String Function(String url, Map<String, dynamic>? body)? getCacheKey;
  final String Function(dynamic responseData)? getDataFromResponseData;

  late final String _cacheKey;
  late final BehaviorSubject<CacheTtlEtagState<T>> _stateController;
  StreamSubscription? _cacheSubscription;
  StreamSubscription? _updateSubscription;

  /// Create a new repository instance
  ///
  /// [url] - The URL to fetch data from
  /// [fromJson] - Function to deserialize JSON to type T
  /// [cache] - Optional ReactiveCacheDio instance (uses singleton by default)
  /// [method] - HTTP method (default: GET)
  /// [body] - Optional request body
  /// [headers] - Optional HTTP headers
  /// [defaultTtl] - Default time-to-live for cache entries
  /// [getCacheKey] - Optional custom cache key generator
  /// [getDataFromResponseData] - Optional response data extractor
  CachedTtlEtagRepository({
    required this.url,
    required this.fromJson,
    ReactiveCacheDio? cache,
    this.method = 'GET',
    this.body,
    this.headers,
    this.defaultTtl,
    this.getCacheKey,
    this.getDataFromResponseData,
  }) : _cache = cache ?? ReactiveCacheDio() {
    _cacheKey =
        getCacheKey?.call(url, body) ?? _cache.generateCacheKey(url, body);
    _stateController = BehaviorSubject<CacheTtlEtagState<T>>.seeded(
      const CacheTtlEtagState(isLoading: true),
    );
    _initialize();
  }

  /// Stream of cache state updates
  ///
  /// Emits a new state whenever the cache is updated, including:
  /// - Data changes
  /// - Loading state changes
  /// - Error state changes
  /// - Stale/TTL status changes
  Stream<CacheTtlEtagState<T>> get stream => _stateController.stream;

  /// Current state snapshot
  CacheTtlEtagState<T> get state => _stateController.value;

  void _initialize() {
    // Watch for cache changes in the database
    _cacheSubscription = _cache.isar.cachedTtlEtagResponses
        .watchLazy(fireImmediately: true)
        .asyncMap((_) => _loadCacheEntry())
        .listen(_updateState);

    // Watch for cache update events
    _updateSubscription = _cache.updateStream.listen((_) {
      // State will be updated via _cacheSubscription
    });

    // Initial fetch
    fetch();
  }

  Future<CachedTtlEtagResponse?> _loadCacheEntry() async {
    return await _cache.isar.cachedTtlEtagResponses
        .filter()
        .urlEqualTo(_cacheKey)
        .findFirst();
  }

  void _updateState(CachedTtlEtagResponse? cached) {
    final currentState = _stateController.value;

    T? data;
    if (cached != null) {
      try {
        // Get data based on encryption status
        String? rawData;
        if (cached.isEncrypted) {
          if (_cache.isEncryptionEnabled) {
            rawData = _cache.getDataFromCache(cached);
          } else {
            // Can't decrypt without encryption enabled
            _stateController.add(currentState.copyWith(
              error:
                  Exception('Cache is encrypted but encryption is not enabled'),
              isLoading: false,
            ));
            return;
          }
        } else {
          rawData = cached.data;
        }

        if (rawData != null) {
          data = fromJson(jsonDecode(rawData));
        }
      } catch (e) {
        _stateController.add(currentState.copyWith(
          error: e,
          isLoading: false,
        ));
        return;
      }
    }

    _stateController.add(CacheTtlEtagState(
      data: data,
      isLoading: currentState.isLoading,
      isStale: cached?.isStale ?? false,
      error: currentState.error,
      timestamp: cached?.timestamp,
      ttlSeconds: cached?.ttlSeconds,
      etag: cached?.etag,
    ));
  }

  /// Fetch data from the network
  ///
  /// This method:
  /// 1. Sets loading state
  /// 2. Calls the cache service to fetch data
  /// 3. Updates state based on success or failure
  ///
  /// [forceRefresh] - If true, ignores cache and forces a network request
  ///
  /// Example:
  /// ```dart
  /// // Normal fetch (uses cache if valid)
  /// await repo.fetch();
  ///
  /// // Force refresh (bypasses cache)
  /// await repo.fetch(forceRefresh: true);
  /// ```
  Future<void> fetch({bool forceRefresh = false}) async {
    _stateController.add(_stateController.value.copyWith(
      isLoading: true,
      error: null,
    ));

    try {
      await _cache.fetchReactive<T>(
        url: url,
        method: method,
        body: body,
        headers: headers,
        defaultTtl: defaultTtl,
        forceRefresh: forceRefresh,
        fromJson: fromJson,
        getCacheKey: getCacheKey,
        getDataFromResponseData: getDataFromResponseData,
      );

      _stateController.add(_stateController.value.copyWith(
        isLoading: false,
        error: null,
      ));
    } catch (e) {
      _stateController.add(_stateController.value.copyWith(
        isLoading: false,
        error: e,
      ));
    }
  }

  /// Force refresh from the network
  ///
  /// Shorthand for `fetch(forceRefresh: true)`
  ///
  /// Example:
  /// ```dart
  /// await repo.refresh();
  /// ```
  Future<void> refresh() => fetch(forceRefresh: true);

  /// Invalidate the cache entry
  ///
  /// This removes the cache entry from storage and emits an update
  ///
  /// Example:
  /// ```dart
  /// await repo.invalidate();
  /// ```
  Future<void> invalidate() async {
    await _cache.invalidate<T>(
      url: url,
      body: body,
      getCacheKey: getCacheKey,
    );
  }

  /// Dispose of the repository
  ///
  /// This cancels all subscriptions and closes the state stream.
  /// Always call this when the repository is no longer needed.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   repo.dispose();
  ///   super.dispose();
  /// }
  /// ```
  void dispose() {
    _cacheSubscription?.cancel();
    _updateSubscription?.cancel();
    _stateController.close();
  }
}
