import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class StockDetailScreen extends StatefulWidget {
  final String symbol;
  const StockDetailScreen({super.key, required this.symbol});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final ApiService _api = ApiService();
  String selectedPeriod = '1m';
  List<FlSpot> chartData = [];
  Map<String, dynamic>? aiInsight;
  bool loadingChart = true;
  bool loadingAI = false;

  final periods = ['1w', '1m', '3m', '6m', '1y'];

  @override
  void initState() {
    super.initState();
    fetchHistory();
    fetchAI();
  }

  Future<void> fetchHistory() async {
    setState(() => loadingChart = true);
    try {
      final data = await _api.getHistory(widget.symbol, selectedPeriod);
      setState(() {
        chartData = data.asMap().entries.map((e) {
          return FlSpot(
            e.key.toDouble(),
            (e.value['price'] as num).toDouble(),
          );
        }).toList();
        loadingChart = false;
      });
    } catch (e) {
      setState(() => loadingChart = false);
    }
  }

  Future<void> fetchAI() async {
    setState(() => loadingAI = true);
    try {
      final data = await _api.getAIInsight(widget.symbol);
      setState(() {
        aiInsight = data;
        loadingAI = false;
      });
    } catch (e) {
      setState(() => loadingAI = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.symbol),
        backgroundColor: const Color(0xFF006B3F),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Period selector
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: periods.map((p) {
                  return ChoiceChip(
                    label: Text(p.toUpperCase()),
                    selected: selectedPeriod == p,
                    selectedColor: const Color(0xFF006B3F),
                    labelStyle: TextStyle(
                      color: selectedPeriod == p ? Colors.white : Colors.black,
                    ),
                    onSelected: (_) {
                      setState(() => selectedPeriod = p);
                      fetchHistory();
                    },
                  );
                }).toList(),
              ),
            ),

            // Chart
            SizedBox(
              height: 250,
              child: loadingChart
                  ? const Center(child: CircularProgressIndicator())
                  : chartData.isEmpty
                      ? const Center(child: Text('No data for this period'))
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: LineChart(
                            LineChartData(
                              gridData: const FlGridData(show: false),
                              titlesData: const FlTitlesData(show: false),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: chartData,
                                  isCurved: true,
                                  color: const Color(0xFF006B3F),
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: const Color(0xFF006B3F)
                                        .withOpacity(0.1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
            ),

            const Divider(),

            // AI Insight
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Text(
                        'AI Insight',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (loadingAI)
                    const Center(child: CircularProgressIndicator())
                  else if (aiInsight != null) ...[
                    // Recommendation badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: aiInsight!['recommendation'] == 'BUY'
                            ? Colors.green.shade100
                            : aiInsight!['recommendation'] == 'SELL'
                                ? Colors.red.shade100
                                : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        aiInsight!['recommendation'] ?? 'HOLD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: aiInsight!['recommendation'] == 'BUY'
                              ? Colors.green.shade800
                              : aiInsight!['recommendation'] == 'SELL'
                                  ? Colors.red.shade800
                                  : Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      aiInsight!['ai_insight'] ?? 'No insight available',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ] else
                    const Text('AI insight unavailable'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}