import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stock_analyzer/Stock_provider.dart';
import 'package:stock_analyzer/stock.dart';

class StockHomePage extends ConsumerStatefulWidget {
  const StockHomePage({super.key});

  @override
  ConsumerState<StockHomePage> createState() => _StockHomePageState();
}

class _StockHomePageState extends ConsumerState<StockHomePage> {
  late final ProviderSubscription _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = ref.listenManual<StockState>(stockProvider, (prev, next) {
      if (next.showNoInternetMessage) {
        _showNoInternetDialog();

        // Reset flag so the snackbar doesn't repeat
        ref.read(stockProvider.notifier).state = next.copyWith(
          showNoInternetMessage: false,
        );
      }
    });
  }

  void _showNoInternetDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("No Internet Connection"),
          content: const Text("Please check your connection and try again."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }

  String _statusToText(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connecting:
        return "Connecting...";
      case ConnectionStatus.connected:
        return "Connected";
      case ConnectionStatus.reconnecting:
        return "Reconnecting...";
      case ConnectionStatus.disconnected:
        return "Disconnected";
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(stockProvider.select((s) => s.connectionStatus));
    final tickers = ref.watch(
      stockProvider.select((s) => s.stockPrices.keys.toList()),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Stock Tracker"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              _statusToText(status),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: tickers.length,
        itemBuilder: (context, index) {
          final ticker = tickers[index];
          return StockTile(ticker: ticker);
        },
      ),
    );
  }
}

class StockTile extends StatelessWidget {
  final String ticker;
  const StockTile({super.key, required this.ticker});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(
        children: [
          Text(ticker),
          const SizedBox(width: 6),
          Consumer(
            builder: (context, ref, _) {
              final isSuspect = ref.watch(
                stockProvider.select((s) => s.suspectTickers.contains(ticker)),
              );
              return isSuspect
                  ? const Icon(Icons.warning, color: Colors.orange, size: 16)
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PriceText(ticker: ticker),
          const SizedBox(width: 6),
          _FlashIndicator(ticker: ticker),
        ],
      ),
    );
  }
}

class _PriceText extends ConsumerWidget {
  final String ticker;
  const _PriceText({super.key, required this.ticker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = ref.watch(stockProvider.select((s) => s.stockPrices[ticker]));
    final color = ref.watch(stockProvider.select((s) => s.stoclColors[ticker]));

    if (color != null) {
      return Text(
        price?.toStringAsFixed(2) ?? '--',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: color,
        ),
      );
    }

    return Text(
      price?.toStringAsFixed(2) ?? '--',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: Colors.black87,
      ),
    );
  }
}

class _FlashIndicator extends ConsumerStatefulWidget {
  final String ticker;
  const _FlashIndicator({super.key, required this.ticker});

  @override
  ConsumerState<_FlashIndicator> createState() => _FlashIndicatorState();
}

class _FlashIndicatorState extends ConsumerState<_FlashIndicator> {
  Color? flashColor;
  Timer? _clearTimer;

  @override
  void didUpdateWidget(covariant _FlashIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ticker != widget.ticker) {
      _clearTimer?.cancel();
      flashColor = null;
    }
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final newColor = ref.watch(
      stockProvider.select((s) => s.stoclColors[widget.ticker]),
    );

    // if (newColor != flashColor && newColor != null) {
    //   flashColor = newColor;
    //   _clearTimer?.cancel();
    //   _clearTimer = Timer(const Duration(milliseconds: 300), () {
    //     if (mounted) {
    //       setState(() {
    //         flashColor = null;
    //       });
    //     }
    //   });

    //   setState(() {});
    // }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: newColor == null
          ? const SizedBox(key: ValueKey('empty'))
          : Icon(
              newColor == Colors.green
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              key: ValueKey(newColor),
              color: flashColor,
              size: 20,
            ),
    );
  }
}
