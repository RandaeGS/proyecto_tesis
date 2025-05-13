import 'package:flutter/material.dart';
import '../screens/reconciliation/services/inventory_reconciliation_service.dart';

class ReconciliationDialog extends StatefulWidget {
  final List<ReconciliationConflict> conflicts;
  final int centerId;
  final Function(List<ReconciliationDecision> decisions) onConfirm;

  const ReconciliationDialog({
    Key? key,
    required this.conflicts,
    required this.centerId,
    required this.onConfirm,
  }) : super(key: key);

  /// Método estático para mostrar el diálogo
  static Future<void> show(
      BuildContext context,
      List<ReconciliationConflict> conflicts,
      int centerId,
      Function(List<ReconciliationDecision> decisions) onConfirm,
      ) async {
    if (conflicts.isEmpty) return;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ReconciliationDialog(
          conflicts: conflicts,
          centerId: centerId,
          onConfirm: onConfirm,
        );
      },
    );
  }

  @override
  State<ReconciliationDialog> createState() => _ReconciliationDialogState();
}

class _ReconciliationDialogState extends State<ReconciliationDialog> {
  List<ReconciliationDecision> _decisions = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _initializeDecisions();
  }

  void _initializeDecisions() {
    _decisions = widget.conflicts.map((conflict) =>
        ReconciliationDecision(
          conflict: conflict,
          action: ReconciliationAction.add,  // Por defecto, añadir a existencias
        )
    ).toList();
  }

  void _updateDecision(int index, ReconciliationAction action) {
    setState(() {
      _decisions[index] = ReconciliationDecision(
        conflict: widget.conflicts[index],
        action: action,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encabezado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sync_problem,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reconciliación de Inventario',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Mensaje explicativo
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Se han detectado ${widget.conflicts.length} productos en imágenes que podrían afectar al inventario actual. Por favor, decide cómo quieres manejar cada uno:',
                style: TextStyle(fontSize: 14),
              ),
            ),

            // Lista de conflictos
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.conflicts.length,
                itemBuilder: (context, index) {
                  final conflict = widget.conflicts[index];
                  final decision = _decisions[index];

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  conflict.category.substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.blue.shade800,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      conflict.category,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Inventario actual: ${conflict.currentInventoryCount}',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      'Detectado en imagen: ${conflict.detectedCount}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),

                          // Opciones de reconciliación
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionOption(
                                  'Añadir',
                                  Icons.add_circle_outline,
                                  Colors.green,
                                  decision.action == ReconciliationAction.add,
                                      () => _updateDecision(index, ReconciliationAction.add),
                                  'Añadir ${conflict.detectedCount} al inventario',
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: _buildActionOption(
                                  'Reemplazar',
                                  Icons.swap_horizontal_circle_outlined,
                                  Colors.orange,
                                  decision.action == ReconciliationAction.replace,
                                      () => _updateDecision(index, ReconciliationAction.replace),
                                  'Establecer el inventario a ${conflict.detectedCount}',
                                ),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: _buildActionOption(
                                  'Ignorar',
                                  Icons.do_not_disturb_alt_outlined,
                                  Colors.grey,
                                  decision.action == ReconciliationAction.ignore,
                                      () => _updateDecision(index, ReconciliationAction.ignore),
                                  'No realizar cambios',
                                ),
                              ),
                            ],
                          ),

                          // Explicación de la acción seleccionada
                          Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              _getActionExplanation(decision.action, conflict),
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: _getActionColor(decision.action),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Botones de acción
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text('Cancelar'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () {
                      setState(() {
                        _isProcessing = true;
                      });
                      widget.onConfirm(_decisions);
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isProcessing
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text('Confirmar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionOption(
      String label,
      IconData icon,
      Color color,
      bool isSelected,
      VoidCallback onTap,
      String tooltip,
      ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.grey,
              ),
              SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getActionExplanation(
      ReconciliationAction action,
      ReconciliationConflict conflict,
      ) {
    switch (action) {
      case ReconciliationAction.add:
        final newTotal = conflict.currentInventoryCount + conflict.detectedCount;
        return 'Se añadirán ${conflict.detectedCount} a los ${conflict.currentInventoryCount} existentes, quedando un total de $newTotal unidades.';

      case ReconciliationAction.replace:
        final diff = conflict.detectedCount - conflict.currentInventoryCount;
        String change = diff > 0
            ? 'un aumento de $diff'
            : diff < 0
            ? 'una disminución de ${diff.abs()}'
            : 'sin cambios';
        return 'Se reemplazará la cantidad actual (${conflict.currentInventoryCount}) por ${conflict.detectedCount}, resultando en $change.';

      case ReconciliationAction.ignore:
        return 'No se modificará el inventario para esta categoría.';
    }
  }

  Color _getActionColor(ReconciliationAction action) {
    switch (action) {
      case ReconciliationAction.add:
        return Colors.green;
      case ReconciliationAction.replace:
        return Colors.orange;
      case ReconciliationAction.ignore:
        return Colors.grey;
    }
  }
}