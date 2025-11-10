import 'dart:async';
import 'dart:convert';
import 'package:isar_community/isar.dart';
import 'package:rxdart/rxdart.dart';
import '../services/reactive_ttl_etag_cache_dio.dart';
import '../models/cached_ttl_etag_response.dart';
import '../models/cache_ttl_etag_state.dart';

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

  /// Stream of cache state with all UI-required data
  Stream<CacheTtlEtagState<T>> get stream => _stateController.stream;

  /// Current state snapshot
  CacheTtlEtagState<T> get state => _stateController.value;

  void _initialize() {
    // Watch for cache changes
    _cacheSubscription = _cache.isar.cachedTtlEtagResponses
        .watchLazy(fireImmediately: true)
        .asyncMap((_) => _loadCacheEntry())
        .listen(_updateState);

    // Watch for reactive updates (fetch completion, invalidation)
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
    if (cached?.data != null) {
      try {
        data = fromJson(jsonDecode(cached!.data));
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

  /// Fetch fresh data from the network
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
  Future<void> refresh() => fetch(forceRefresh: true);

  /// Invalidate the cache
  Future<void> invalidate() async {
    await _cache.invalidate<T>(
      url: url,
      body: body,
      getCacheKey: getCacheKey,
    );
  }

  /// Dispose of the repository
  void dispose() {
    _cacheSubscription?.cancel();
    _updateSubscription?.cancel();
    _stateController.close();
  }
}
