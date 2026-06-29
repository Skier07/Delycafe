import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinCodeInput extends StatefulWidget {
  const PinCodeInput({
    super.key,
    required this.length,
    required this.onCompleted,
    this.enabled = true,
    this.autofocus = true,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final bool enabled;
  final bool autofocus;

  @override
  State<PinCodeInput> createState() => PinCodeInputState();
}

class PinCodeInputState extends State<PinCodeInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

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

  void _onDigitChanged(int index, String value) {
    if (!widget.enabled) {
      return;
    }

    if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else if (this.value.length == widget.length) {
        widget.onCompleted(this.value);
      }
    } else if (index > 0) {
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
    return Row(
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
              maxLength: 1,
              obscureText: true,
              obscuringCharacter: '•',
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
  }
}
