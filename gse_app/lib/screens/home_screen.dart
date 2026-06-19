import 'package:flutter/material.dart';
import 'package:gse_app/screens/alerts_screen.dart';
import '../services/api_service.dart';
import 'stock_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> stocks = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchStocks();
  }

  Future<void> fetchStocks() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final data = await _api.getStocks();
      setState(() {
        stocks = data;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GSE Stocks'),
        backgroundColor: const Color(0xFF006B3F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: (){
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlertsScreen()),
                );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchStocks,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: fetchStocks,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchStocks,
      child: ListView.separated(
        itemCount: stocks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final stock = stocks[index];
          final price = (stock['price'] ?? 0).toDouble();
          final change = (stock['change_value'] ?? 0).toDouble();
          final changePercent = (stock['change_percent'] ?? 0).toDouble();
          final volume = stock['volume'] ?? 0;
          final symbol = stock['symbol'] ?? '';
          final name = stock['name'] ?? symbol;

          return ListTile(
            title: Text(
              symbol,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('$name • Vol: $volume'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'GHS ${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)} (${changePercent.toStringAsFixed(1)}%)',
                  style: TextStyle(
                    color: change > 0
                        ? Colors.green
                        : change < 0
                            ? Colors.red
                            : Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StockDetailScreen(symbol: symbol),
                ),
              );
            },
          );
        },
      ),
    );
  }
}