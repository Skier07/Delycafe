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
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _lastCompletedValue;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController();
    _focusNode = FocusNode()..addListener(_handleFocusChanged);

    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.enabled) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  void clear() {
    _controller.clear();
    _lastCompletedValue = null;
    setState(() {});

    if (widget.enabled) {
      _focusNode.requestFocus();
    }
  }

  String get value => _controller.text;

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onChanged(String value) {
    if (!widget.enabled) {
      return;
    }

    setState(() {});

    if (value.length < widget.length) {
      _lastCompletedValue = null;
    } else if (value.length == widget.length && _lastCompletedValue != value) {
      _lastCompletedValue = value;
      widget.onCompleted(value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final input = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.length * 60 + (widget.length - 1) * 16,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final desiredWidth = widget.length * 60 + (widget.length - 1) * 16;
            final totalWidth = constraints.maxWidth < desiredWidth
                ? constraints.maxWidth
                : desiredWidth.toDouble();
            final gap = totalWidth < 280 ? 8.0 : 16.0;
            final boxWidth =
                (totalWidth - gap * (widget.length - 1)) / widget.length;
            final currentValue = _controller.text;
            final activeIndex = currentValue.length >= widget.length
                ? widget.length - 1
                : currentValue.length;

            return SizedBox(
              width: totalWidth,
              height: 64,
              child: Stack(
                children: [
                  IgnorePointer(
                    child: Row(
                      children: List.generate(widget.length, (index) {
                        final hasValue = index < currentValue.length;
                        final isActive =
                            _focusNode.hasFocus && index == activeIndex;

                        return Padding(
                          padding: EdgeInsets.only(
                            right: index < widget.length - 1 ? gap : 0,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: boxWidth,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: widget.enabled
                                  ? Colors.transparent
                                  : Theme.of(context)
                                      .disabledColor
                                      .withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isActive
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                                width: isActive ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              hasValue
                                  ? (widget.obscureText
                                      ? '•'
                                      : currentValue[index])
                                  : '',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.01,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        enabled: widget.enabled,
                        autofocus: false,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        maxLength: widget.length,
                        showCursor: false,
                        autofillHints: widget.enableSmsAutofill
                            ? const [AutofillHints.oneTimeCode]
                            : null,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(widget.length),
                        ],
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: _onChanged,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (!widget.enableSmsAutofill) {
      return input;
    }

    return AutofillGroup(child: input);
  }
}
