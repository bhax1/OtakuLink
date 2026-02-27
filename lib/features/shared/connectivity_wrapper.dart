import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/network_repository.dart';
import '../../core/utils/app_snackbar.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  final _repository = NetworkRepository(); 
  late StreamSubscription<NetworkStatus> _subscription;
  
  // Track if we've actually lost connection at least once
  bool _hasBeenOffline = false;

  @override
  void initState() {
    super.initState();
    _subscription = _repository.statusStream.listen((status) {
      _handleStatusChange(status);
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _handleStatusChange(NetworkStatus status) {
    if (!mounted) return;

    if (status == NetworkStatus.offline) {
      _hasBeenOffline = true; // User is now officially disconnected
      _showStatus("No Internet Connection", isError: true);
    } else {
      // Only show "Back Online" if the flag was previously set to true
      if (_hasBeenOffline) {
        _showStatus("Back Online", isError: false);
        _hasBeenOffline = false; // Reset the flag
      }
    }
  }

  void _showStatus(String message, {required bool isError}) {
    // Clear any existing snackbar immediately (especially the infinite offline one)
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    AppSnackBar.show(
      context,
      message,
      type: isError ? SnackBarType.error : SnackBarType.success,
      // Infinite duration for offline, standard for back online
      duration: isError ? const Duration(days: 365) : const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}