class Stock {
  final String ticker;
  final double price;

  Stock(this.ticker, this.price);
}

enum ConnectionStatus { connecting, connected, reconnecting, disconnected }
