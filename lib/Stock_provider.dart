import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_analyzer/stock.dart';
import 'package:web_socket_channel/io.dart';

class StockState {
  final Map<String, double> stockPrices;
  final Map<String, Color> stoclColors;
  final ConnectionStatus connectionStatus;
  final bool showNoInternetMessage;
  Set<String> suspectTickers;

  StockState({
    required this.stockPrices,
    required this.stoclColors,
    required this.connectionStatus,
    this.showNoInternetMessage = false,
    this.suspectTickers = const {},
  });

  StockState copyWith({
    Map<String, double>? stockPrices,
    Map<String, Color>? stoclColors,
    ConnectionStatus? connectionStatus,
    bool? showNoInternetMessage,
    Set<String>? suspectTickers,
  }) {
    return StockState(
      stockPrices: stockPrices ?? this.stockPrices,
      stoclColors: stoclColors ?? this.stoclColors,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      showNoInternetMessage:
          showNoInternetMessage ?? this.showNoInternetMessage,
      suspectTickers: suspectTickers ?? this.suspectTickers,
    );
  }
}

class StockNotifier extends StateNotifier<StockState> {
  StockNotifier()
    : super(
        StockState(
          stockPrices: {},
          stoclColors: {},
          connectionStatus: ConnectionStatus.connecting,
        ),
      ) {
    _startMonitoringConnection();
    _connect();
  }

  IOWebSocketChannel? _channel;
  Timer? _reconnectTimer;
  int _retrySeconds = 2;

  void _startMonitoringConnection() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        debugPrint('[WebSocket] No internet. Skipping connection.');
        state = state.copyWith(
          connectionStatus: ConnectionStatus.disconnected,
          showNoInternetMessage: true,
        );
        return;
      }
    });
  }

  Future<void> _connect() async {
    _updateStatus(ConnectionStatus.connecting);

    final result = await Connectivity().checkConnectivity();
    if (result == ConnectivityResult.none) {
      debugPrint('[WebSocket] No internet. Skipping connection.');
      _updateStatus(ConnectionStatus.disconnected);

      return;
    }

    try {
      _channel = IOWebSocketChannel.connect('ws://192.168.1.5:8080/ws');
      debugPrint('[WebSocket] Connected');

      _updateStatus(ConnectionStatus.connected);

      _channel!.stream.listen(
        _onData,
        onDone: () {
          debugPrint('[WebSocket] Closed by server');
          _onDisconnected();
        },
        onError: (error) {
          debugPrint('[WebSocket] Error: $error');
          _onDisconnected();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[WebSocket] Exception: $e');
      _onDisconnected();
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    super.dispose();
  }

  void _onDisconnected() {
    _updateStatus(ConnectionStatus.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _retrySeconds), _connect);
    _retrySeconds = min(_retrySeconds * 2, 30);
  }

  void _onData(dynamic data) {
    try {
      if (data is String && data.isEmpty) return;

      final decoded = jsonDecode(data);
      if (decoded is! List) return;

      final updatedPrices = Map<String, double>.from(state.stockPrices);
      final flashColors = Map<String, Color>.from(state.stoclColors);
      final suspectTickers = Set<String>.from(state.suspectTickers);

      for (var entry in decoded) {
        final ticker = entry['ticker'];
        final price = double.tryParse(entry['price'].toString());

        if (ticker == null || price == null) continue;

        final previous = updatedPrices[ticker];
        final anomolies = previous != null && price < previous * 0.1;

        if (anomolies) {
          suspectTickers.add(ticker);
          continue;
        } else {
          suspectTickers.remove(ticker);
        }

        updatedPrices[ticker] = price;

        if (previous != null) {
          if (price > previous) {
            flashColors[ticker] = Colors.green;
          } else if (price < previous) {
            flashColors[ticker] = Colors.red;
          }

          Timer(const Duration(milliseconds: 500), () {
            flashColors.remove(ticker);
            state = state.copyWith(stoclColors: Map.from(flashColors));
          });
        }
      }

      state = state.copyWith(
        stockPrices: updatedPrices,
        stoclColors: flashColors,
        suspectTickers: suspectTickers,
      );
    } catch (e) {
      debugPrint('[WebSocket] Invalid JSON or error: $e');
    }
  }

  void _updateStatus(ConnectionStatus status) {
    state = state.copyWith(connectionStatus: status);
  }
}

final stockProvider = StateNotifierProvider<StockNotifier, StockState>(
  (ref) => StockNotifier(),
);
