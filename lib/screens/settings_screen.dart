import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final String title;
  final String type; // 'CMD', 'POWER', 'PF'
  final double currentLimit;
  final double? currentMaxGauge;

  const SettingsScreen({
    super.key,
    required this.title,
    required this.type,
    required this.currentLimit,
    this.currentMaxGauge,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _limitController;
  late TextEditingController _maxGaugeController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _limitController = TextEditingController(text: widget.currentLimit.toString());
    _maxGaugeController = TextEditingController(text: widget.currentMaxGauge?.toString() ?? '');
  }

  @override
  void dispose() {
    _limitController.dispose();
    _maxGaugeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Adjust ${widget.type} Parameters', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 24),
            TextField(
              controller: _limitController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Limit (${widget.type == 'PF' ? '' : widget.type == 'CMD' ? 'kVA' : 'kW'})',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.speed),
              ),
            ),
            const SizedBox(height: 20),
            if (widget.type != 'PF') // Gauge settings only for CMD/POWER
              TextField(
                controller: _maxGaugeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Max Gauge Value',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.linear_scale),
                ),
              ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSaving ? null : () async {
                final double? newLimit = double.tryParse(_limitController.text);
                final double? newMaxGauge = widget.type != 'PF' 
                    ? double.tryParse(_maxGaugeController.text) 
                    : null;

                if (newLimit != null) {
                  // Check if values actually changed
                  final bool limitChanged = newLimit != widget.currentLimit;
                  final bool maxGaugeChanged = widget.type != 'PF' && newMaxGauge != widget.currentMaxGauge;

                  if (!limitChanged && !maxGaugeChanged) {
                    Navigator.pop(context); // Close without doing anything
                    return;
                  }

                  // Show Confirmation Dialog
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Change'),
                      content: Text('Are you sure you want to change the ${widget.type} settings?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('YES, CHANGE', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ) ?? false;

                  if (confirmed) {
                    if (mounted) {
                      setState(() => _isSaving = true);
                      Navigator.pop(context, {
                        'limit': newLimit,
                        'maxGauge': newMaxGauge,
                      });
                    }
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid numeric value')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}
