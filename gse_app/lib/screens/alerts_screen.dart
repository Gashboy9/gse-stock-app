import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final ApiService _api = ApiService();
  List<Map<String, dynamic>> alerts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchAlerts();
  }

  Future<void> fetchAlerts() async {
    setState(() => loading = true);
    try {
      final data = await _api.getAlerts(1); // TODO: use real user ID
      setState(() {
        alerts = data;
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
    }
  }

  Future<void> _showCreateAlertDialog() async {
    String? selectedSymbol;
    String alertType = 'price_above';
    final priceController = TextEditingController();

    // Get stock list for dropdown
    List<Map<String, dynamic>> stocks = [];
    try {
      stocks = await _api.getStocks();
    } catch (e) {
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Price Alert'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stock selector
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Stock'),
                items: stocks.map((s) {
                  return DropdownMenuItem(
                    value: s['symbol'] as String,
                    child: Text('${s['symbol']} - GHS ${s['price']}'),
                  );
                }).toList(),
                onChanged: (val) => setDialogState(() => selectedSymbol = val),
              ),
              const SizedBox(height: 16),

              // Alert type
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

              // Target price
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
                if (selectedSymbol != null &&
                    priceController.text.isNotEmpty) {
                  try {
                    await _api.createAlert(
                      userId: 1, // TODO: use real user ID
                      symbol: selectedSymbol!,
                      alertType: alertType,
                      targetValue: double.parse(priceController.text),
                    );
                    Navigator.pop(context);
                    fetchAlerts();
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
        title: const Text('My Alerts'),
        backgroundColor: const Color(0xFF006B3F),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateAlertDialog,
        backgroundColor: const Color(0xFF006B3F),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : alerts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off,
                          size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No alerts set',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Tap + to create a price alert',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: alerts.length,
                  itemBuilder: (context, index) {
                    final alert = alerts[index];
                    final isAbove = alert['alert_type'] == 'price_above';
                    return ListTile(
                      leading: Icon(
                        isAbove ? Icons.trending_up : Icons.trending_down,
                        color: isAbove ? Colors.green : Colors.red,
                      ),
                      title: Text(alert['symbol']),
                      subtitle: Text(
                        '${isAbove ? "Above" : "Below"} GHS ${alert['target_value']}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          await _api.deleteAlert(alert['id']);
                          fetchAlerts();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}