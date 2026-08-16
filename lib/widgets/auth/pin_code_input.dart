import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinCodeInput extends StatefulWidget {
  const PinCodeInput({
    super.key,
    required this.length,
    required this.onCompleted,
    this.enabled = true,
    this.autofocus = true,
    this.obscureText = true,
    this.enableSmsAutofill = false,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final bool enabled;
  final bool autofocus;
  final bool obscureText;
  final bool enableSmsAutofill;

  @override
  State<PinCodeInput> createState() => PinCodeInputState();
}

class PinCodeInputState extends State<PinCodeInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  bool _isDistributing = false;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) {
          _focusNodes.first.requestFocus();
        }
      });
    }
  }

  void clear() {
    for (final controller in _controllers) {
      controller.clear();
    }

    if (widget.enabled) {
      _focusNodes.first.requestFocus();
    }
  }

  String get value => _controllers.map((controller) => controller.text).join();

  void _distributeDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return;
    }

    _isDistributing = true;
    try {
      final code = digits.length > widget.length
          ? digits.substring(0, widget.length)
          : digits;

      for (var i = 0; i < widget.length; i++) {
        _controllers[i].text = i < code.length ? code[i] : '';
      }

      if (code.length >= widget.length) {
        _focusNodes[widget.length - 1].unfocus();
        widget.onCompleted(code.substring(0, widget.length));
      } else {
        _focusNodes[code.length].requestFocus();
      }
    } finally {
      _isDistributing = false;
    }
  }

  void _onDigitChanged(int index, String value) {
    if (!widget.enabled || _isDistributing) {
      return;
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length > 1) {
      _distributeDigits(digits);
      return;
    }

    if (digits.length == 1) {
      if (_controllers[index].text != digits) {
        _controllers[index].value = TextEditingValue(
          text: digits,
          selection: const TextSelection.collapsed(offset: 1),
        );
      }

      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else if (this.value.length == widget.length) {
        widget.onCompleted(this.value);
      }
      return;
    }

    _controllers[index].clear();
    if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  KeyEventResult _onDigitKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }

    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fields = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.length, (index) {
        return Container(
          width: 60,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Focus(
            onKeyEvent: (node, event) => _onDigitKeyEvent(index, event),
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              obscureText: widget.obscureText,
              obscuringCharacter: '•',
              autofillHints: widget.enableSmsAutofill && index == 0
                  ? const [AutofillHints.oneTimeCode]
                  : null,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              onChanged: (value) => _onDigitChanged(index, value),
            ),
          ),
        );
      }),
    );

    if (!widget.enableSmsAutofill) {
      return fields;
    }

    return AutofillGroup(child: fields);
  }
}
