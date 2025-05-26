import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  Future<void> initialize() async {
    // Check initial connectivity
    await _checkInitialConnectivity();
    
    // Listen for connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
      onError: (error) {
        print('Connectivity stream error: $error');
      },
    );
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final ConnectivityResult result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print('Error checking initial connectivity: $e');
      _updateConnectionStatus(ConnectivityResult.none);
    }
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    final bool wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;

    // Only emit if the connection status actually changed
    if (wasConnected != _isConnected) {
      _connectionController.add(_isConnected);
      print('Connection status changed: ${_isConnected ? 'Connected' : 'Disconnected'}');
    }
  }

  Future<bool> hasInternetConnection() async {
    try {
      final ConnectivityResult result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('Error checking internet connection: $e');
      return false;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectionController.close();
  }
}

class NoInternetDialog extends StatefulWidget {
  final VoidCallback? onRetry;

  const NoInternetDialog({Key? key, this.onRetry}) : super(key: key);

  @override
  State<NoInternetDialog> createState() => _NoInternetDialogState();
}

class _NoInternetDialogState extends State<NoInternetDialog> {
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    if (_isRetrying || widget.onRetry == null) return;
    
    setState(() {
      _isRetrying = true;
    });
    
    // Add a small delay for better UX
    await Future.delayed(Duration(milliseconds: 500));
    
    widget.onRetry!();
    
    // Reset the state after a delay
    await Future.delayed(Duration(milliseconds: 1000));
    
    if (mounted) {
      setState(() {
        _isRetrying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing with back button
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.signal_wifi_off, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'This app requires an internet connection to function properly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton.icon(
              onPressed: _isRetrying ? null : _handleRetry,
              icon: _isRetrying 
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.refresh, color: Colors.white),
              label: Text(
                _isRetrying ? 'Checking...' : 'Try Again',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRetrying ? Colors.grey : Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
