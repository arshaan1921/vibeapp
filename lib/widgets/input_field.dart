import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InputField extends StatelessWidget {
  final String label;
  final bool isPassword;
  final TextEditingController? controller;
  final int maxLines;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? hintText;

  const InputField({
    super.key,
    required this.label,
    this.isPassword = false,
    this.controller,
    this.maxLines = 1,
    this.keyboardType,
    this.inputFormatters,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          decoration: InputDecoration(
            hintText: hintText ?? 'Type your $label...',
            hintStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
            filled: true,
            fillColor: Theme.of(context).cardColor,
          ),
        ),
      ],
    );
  }
}
