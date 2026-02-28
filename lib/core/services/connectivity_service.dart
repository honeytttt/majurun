import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Service for monitoring network connectivity
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  Timer? _checkTimer;

  /// Start monitoring connectivity
  void startMonitoring({Duration interval = const Duration(seconds: 10)}) {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(interval, (_) => checkConnectivity());
    // Initial check
    checkConnectivity();
  }

  /// Stop monitoring
  void stopMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  /// Check current connectivity
  Future<bool> checkConnectivity() async {
    try {
      if (kIsWeb) {
        // On web, assume connected (browser handles this)
        _updateConnectivity(true);
        return true;
      }

      // Try to reach a reliable host
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));

      final connected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _updateConnectivity(connected);
      return connected;
    } on SocketException catch (_) {
      _updateConnectivity(false);
      return false;
    } on TimeoutException catch (_) {
      _updateConnectivity(false);
      return false;
    } catch (e) {
      debugPrint('Connectivity check error: $e');
      _updateConnectivity(false);
      return false;
    }
  }

  void _updateConnectivity(bool connected) {
    if (_isConnected != connected) {
      _isConnected = connected;
      _connectivityController.add(connected);
      debugPrint('Connectivity changed: ${connected ? "Online" : "Offline"}');
    }
  }

  /// Execute operation with connectivity check
  Future<T?> executeOnline<T>(
    Future<T> Function() operation, {
    T? offlineDefault,
    void Function()? onOffline,
  }) async {
    final connected = await checkConnectivity();
    if (!connected) {
      onOffline?.call();
      return offlineDefault;
    }
    return operation();
  }

  void dispose() {
    _checkTimer?.cancel();
    _connectivityController.close();
  }
}

/// Mixin for widgets that need connectivity awareness
mixin ConnectivityAware<T extends StatefulWidget> on State<T> {
  late StreamSubscription<bool> _connectivitySubscription;
  bool _isOnline = true;

  bool get isOnline => _isOnline;

  @override
  void initState() {
    super.initState();
    _isOnline = ConnectivityService().isConnected;
    _connectivitySubscription = ConnectivityService().connectivityStream.listen((connected) {
      if (mounted) {
        setState(() => _isOnline = connected);
        onConnectivityChanged(connected);
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  /// Override this to handle connectivity changes
  void onConnectivityChanged(bool isConnected) {}
}
