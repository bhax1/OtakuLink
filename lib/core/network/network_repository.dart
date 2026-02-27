import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkStatus { online, offline }

class NetworkRepository {
  // Singleton pattern (optional, but useful for global services)
  static final NetworkRepository _instance = NetworkRepository._internal();
  factory NetworkRepository() => _instance;
  NetworkRepository._internal() {
    // Start listening immediately upon creation
    _connectivity.onConnectivityChanged.listen(_checkConnection);
  }

  final Connectivity _connectivity = Connectivity();
  
  // Use a broadcast controller so multiple widgets can listen if needed
  final _controller = StreamController<NetworkStatus>.broadcast();
  
  // Expose the stream to the outside world
  Stream<NetworkStatus> get statusStream => _controller.stream;

  // Track last status to avoid spamming the stream with duplicate events
  NetworkStatus? _lastStatus;

  Future<void> _checkConnection(List<ConnectivityResult> results) async {
    NetworkStatus currentStatus = NetworkStatus.online;

    // 1. Physical Check
    if (results.contains(ConnectivityResult.none)) {
      currentStatus = NetworkStatus.offline;
    } else {
      // 2. Data Check (Ping Google)
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          currentStatus = NetworkStatus.online;
        } else {
          currentStatus = NetworkStatus.offline;
        }
      } on SocketException catch (_) {
        currentStatus = NetworkStatus.offline;
      }
    }

    // 3. Emit only if changed
    if (_lastStatus != currentStatus) {
      _lastStatus = currentStatus;
      _controller.add(currentStatus);
    }
  }

  void dispose() {
    _controller.close();
  }
}