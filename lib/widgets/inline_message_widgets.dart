// lib/widgets/inline_message_widgets.dart
import 'package:flutter/material.dart';
import '../color/colors.dart';

/// A collection of reusable inline message widgets for consistent error/success handling
class InlineMessageWidgets {

  /// Creates an inline error message widget to display below form fields
  static Widget buildInlineError(String? errorMessage) {
    if (errorMessage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Text(
        errorMessage,
        style: const TextStyle(
          color: Colors.red,
          fontSize: 12,
        ),
      ),
    );
  }

  /// Creates an inline success message widget
  static Widget buildInlineSuccess(String? successMessage) {
    if (successMessage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4),
      child: Text(
        successMessage,
        style: const TextStyle(
          color: Colors.green,
          fontSize: 12,
        ),
      ),
    );
  }

  /// Creates a banner-style error message for general errors
  static Widget buildErrorBanner(String? errorMessage, {VoidCallback? onDismiss}) {
    if (errorMessage == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 14,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red, size: 18),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  /// Creates a banner-style success message
  static Widget buildSuccessBanner(String? successMessage, {VoidCallback? onDismiss}) {
    if (successMessage == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.secondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              successMessage,
              style: const TextStyle(
                color: AppColors.secondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.secondary, size: 18),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  /// Creates an info banner for informational messages (like email sent confirmation)
  static Widget buildInfoBanner(String message, {String? title, IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Row(
              children: [
                Icon(icon ?? Icons.email, color: AppColors.secondary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          if (title != null) const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// Creates a warning banner for warning messages
  static Widget buildWarningBanner(String? warningMessage) {
    if (warningMessage == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.orange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              warningMessage,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced TextFormField that includes integrated error styling and inline error display
class ErrorAwareTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const ErrorAwareTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          enabled: enabled,
          maxLines: maxLines,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(
            labelText: labelText,
            labelStyle: TextStyle(
              color: hasError ? Colors.red : Colors.grey,
            ),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.transparent,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.transparent,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red : AppColors.secondary,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.grey),
            ),
            suffixIcon: suffixIcon,
          ),
        ),
        InlineMessageWidgets.buildInlineError(errorText),
      ],
    );
  }
}

/// Password field with integrated visibility toggle and strength indicator
class PasswordFormField extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final String? errorText;
  final String? strengthIndicator;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;
  final bool showStrengthIndicator;

  const PasswordFormField({
    super.key,
    required this.controller,
    required this.labelText,
    this.errorText,
    this.strengthIndicator,
    this.onChanged,
    this.validator,
    this.showStrengthIndicator = false,
  });

  @override
  State<PasswordFormField> createState() => _PasswordFormFieldState();
}

class _PasswordFormFieldState extends State<PasswordFormField> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;

    Color strengthColor = Colors.grey;
    if (widget.strengthIndicator != null) {
      if (widget.strengthIndicator!.startsWith("Weak")) {
        strengthColor = Colors.red;
      } else if (widget.strengthIndicator!.startsWith("Fair")) {
        strengthColor = Colors.orange;
      } else if (widget.strengthIndicator!.startsWith("Strong")) {
        strengthColor = Colors.green;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          style: const TextStyle(color: Colors.white),
          obscureText: _obscurePassword,
          onChanged: widget.onChanged,
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: widget.labelText,
            labelStyle: TextStyle(
              color: hasError ? Colors.red : Colors.grey,
            ),
            filled: true,
            fillColor: const Color(0xFF1A2332),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.transparent,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red : Colors.transparent,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? Colors.red : AppColors.secondary,
                width: 2,
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
        ),

        // Error message takes priority over strength indicator
        if (hasError)
          InlineMessageWidgets.buildInlineError(widget.errorText)
        else if (widget.showStrengthIndicator && widget.strengthIndicator != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              widget.strengthIndicator!,
              style: TextStyle(
                color: strengthColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

/// Utility class for managing form error states
class FormErrorState {
  final Map<String, String> _errors = {};

  /// Set an error for a specific field
  void setError(String field, String message) {
    _errors[field] = message;
  }

  /// Get error for a specific field
  String? getError(String field) {
    return _errors[field];
  }

  /// Clear error for a specific field
  void clearError(String field) {
    _errors.remove(field);
  }

  /// Clear all errors
  void clearAllErrors() {
    _errors.clear();
  }

  /// Check if any errors exist
  bool hasErrors() {
    return _errors.isNotEmpty;
  }

  /// Check if a specific field has an error
  bool hasError(String field) {
    return _errors.containsKey(field);
  }

  /// Get all error messages
  List<String> getAllErrors() {
    return _errors.values.toList();
  }
}

/// Helper mixin for managing inline error states in StatefulWidgets
mixin InlineErrorMixin<T extends StatefulWidget> on State<T> {
  final FormErrorState _errorState = FormErrorState();

  /// Set an error for a specific field and trigger rebuild
  void setFieldError(String field, String message) {
    setState(() {
      _errorState.setError(field, message);
    });
  }

  /// Clear error for a specific field and trigger rebuild
  void clearFieldError(String field) {
    setState(() {
      _errorState.clearError(field);
    });
  }

  /// Clear all errors and trigger rebuild
  void clearAllFieldErrors() {
    setState(() {
      _errorState.clearAllErrors();
    });
  }

  /// Get error message for a field
  String? getFieldError(String field) {
    return _errorState.getError(field);
  }

  /// Check if field has error
  bool hasFieldError(String field) {
    return _errorState.hasError(field);
  }

  /// Clear errors when user starts typing
  void onFieldChanged(String field, String value) {
    if (hasFieldError(field)) {
      clearFieldError(field);
    }
  }
}