import 'package:delycafe/widgets/auth/pin_code_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildInput({
    required ValueChanged<String> onCompleted,
    bool enableSmsAutofill = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 272,
            child: PinCodeInput(
              length: 4,
              enableSmsAutofill: enableSmsAutofill,
              onCompleted: onCompleted,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('accepts four digits entered manually', (tester) async {
    String? completed;
    await tester.pumpWidget(
      buildInput(onCompleted: (value) => completed = value),
    );

    final input = find.byType(TextField);
    await tester.enterText(input, '1');
    await tester.enterText(input, '12');
    await tester.enterText(input, '123');
    await tester.enterText(input, '1234');

    expect(completed, '1234');
    expect(tester.takeException(), isNull);
  });

  testWidgets('accepts a complete SMS code in one insertion', (tester) async {
    String? completed;
    await tester.pumpWidget(
      buildInput(
        enableSmsAutofill: true,
        onCompleted: (value) => completed = value,
      ),
    );

    await tester.enterText(find.byType(TextField), '5678');

    expect(completed, '5678');
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits four cells on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildInput(onCompleted: (_) {}));

    expect(tester.takeException(), isNull);
  });
}
