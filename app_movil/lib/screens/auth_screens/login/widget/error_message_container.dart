import 'package:flutter/material.dart';

enum ErrorType {
  error,
  warning,
  info,
}

class ErrorMessageContainer extends StatelessWidget {
  final String message;
  final ErrorType type;
  final IconData? icon;

  const ErrorMessageContainer({
    Key? key,
    required this.message,
    this.type = ErrorType.error,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Configurar colores y iconos según el tipo de error
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    IconData messageIcon;

    switch (type) {
      case ErrorType.error:
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red.shade200;
        textColor = Colors.red.shade800;
        messageIcon = icon ?? Icons.error_outline;
        break;
      case ErrorType.warning:
        backgroundColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade200;
        textColor = Colors.orange.shade800;
        messageIcon = icon ?? Icons.warning_amber_outlined;
        break;
      case ErrorType.info:
        backgroundColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        textColor = Colors.blue.shade800;
        messageIcon = icon ?? Icons.info_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(messageIcon, color: textColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}