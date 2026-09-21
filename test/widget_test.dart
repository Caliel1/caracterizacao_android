import 'package:flutter_test/flutter_test.dart';

import 'package:caracterizacao_android/main.dart';

void main() {
  testWidgets(
    'A aplicação inicia corretamente',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const CharacterizationApp(),
      );

      expect(
        find.text('Caracterização do Android'),
        findsOneWidget,
      );
    },
  );
}