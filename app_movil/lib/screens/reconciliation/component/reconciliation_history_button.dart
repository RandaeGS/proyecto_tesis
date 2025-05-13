import 'package:flutter/material.dart';

import '../screen/reconciliation_history_screen.dart';

class ReconciliationHistoryButton extends StatelessWidget {
  final int centerId;

  const ReconciliationHistoryButton({
    Key? key,
    required this.centerId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReconciliationHistoryScreen(
              centerId: centerId,
            ),
          ),
        );
      },
      icon: const Icon(Icons.history),
      label: const Text('Historial de reconciliación'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.blue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}