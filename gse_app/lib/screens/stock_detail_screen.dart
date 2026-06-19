import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import 'ai_chat_screen.dart';

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
  List<String> _dates = [];
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
        _dates = data.map((e) {
          final date = e['recorded_at'] ?? '';
          // Show just day/month from the timestamp
          if (date.length >= 10) {
            return '${date.substring(8, 10)}/${date.substring(5, 7)}';
          }
          return date;
        }).toList().cast<String>();
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

  Future<void> _showAlertDialog() async {
  String alertType = 'price_above';
  final priceController = TextEditingController();

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('Set Alert for ${widget.symbol}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Alert when'),
              value: alertType,
              items: const [
                DropdownMenuItem(
                  value: 'price_above',
                  child: Text('Price goes above'),
                ),
                DropdownMenuItem(
                  value: 'price_below',
                  child: Text('Price drops below'),
                ),
              ],
              onChanged: (val) =>
                  setDialogState(() => alertType = val ?? 'price_above'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Target price (GHS)',
                prefixText: 'GHS ',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (priceController.text.isNotEmpty) {
                try {
                  await _api.createAlert(
                    userId: 1,
                    symbol: widget.symbol,
                    alertType: alertType,
                    targetValue: double.parse(priceController.text),
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Alert created!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006B3F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.symbol),
        backgroundColor: const Color(0xFF006B3F),
        foregroundColor: Colors.white,
        actions: [
          IconButton (
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (_) => AIChatScreen (symbol: widget.symbol),
                  ),
                );
            },
          ),
          IconButton (
            icon: const Icon(Icons.notification_add),
            onPressed: () => _showAlertDialog(),
            ),
        ],
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
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 1,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                    color: Colors.grey.shade300,
                                    strokeWidth: 0.5,
                                  );
                                },
                              ),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  axisNameWidget: const Text('GHS', style: TextStyle(fontSize: 10)),
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 45,
                                    getTitlesWidget: (value, meta) {
                                      return Text(
                                        value.toStringAsFixed(2),
                                        style: const TextStyle(fontSize: 10),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  axisNameWidget: const Text('Date', style: TextStyle(fontSize: 10)),
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 30,
                                    interval: chartData.length > 10 ? (chartData.length / 5).ceilToDouble() : 1,
                                    getTitlesWidget: (value, meta) {
                                      final index = value.toInt();
                                      if (index < 0 || index >= _dates.length) return const Text('');
                                      return Transform.rotate(
                                        angle: -0.5,
                                        child: Text(
                                          _dates[index],
                                          style: const TextStyle(fontSize: 9),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(
                                show: true,
                                border: Border(
                                  bottom: BorderSide(color: Colors.grey.shade400),
                                  left: BorderSide(color: Colors.grey.shade400),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: chartData,
                                  isCurved: true,
                                  color: const Color(0xFF006B3F),
                                  barWidth: 2,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: const Color(0xFF006B3F).withOpacity(0.1),
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