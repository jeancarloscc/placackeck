// Testes de widget e de validação da tela de consulta de placas.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:placacheck/controllers/vehicle_controller.dart';
import 'package:placacheck/main.dart';
import 'package:placacheck/repositories/vehicle_repository.dart';

void main() {
  testWidgets('Tela inicial exibe o campo de placa e o botão Consultar',
      (WidgetTester tester) async {
    final controller = VehicleController(MockVehicleRepository());
    await tester.pumpWidget(PlacaCheckApp(controller: controller));

    expect(find.text('PlacaCheck'), findsOneWidget);
    expect(find.text('Consultar'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Consulta principal (AAA1A11) mostra dados cadastrais',
      (WidgetTester tester) async {
    final controller = VehicleController(MockVehicleRepository());
    await tester.pumpWidget(PlacaCheckApp(controller: controller));

    await tester.enterText(find.byType(TextField), 'AAA1A11');
    await tester.tap(find.text('Consultar'));
    await tester.pump(); // entra em loading
    await tester.pump(const Duration(seconds: 1)); // aguarda o mock (800ms)

    expect(find.text('Honda Civic'), findsOneWidget);
    expect(find.text('93HFC2670LZ207788'), findsOneWidget); // chassi
    expect(find.text('Consultas adicionais'), findsOneWidget);
  });

  testWidgets('Consulta opcional de roubo (BBB2B22) roda sob demanda',
      (WidgetTester tester) async {
    final controller = VehicleController(MockVehicleRepository());
    await tester.pumpWidget(PlacaCheckApp(controller: controller));

    await tester.enterText(find.byType(TextField), 'BBB2B22');
    await tester.tap(find.text('Consultar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Antes de tocar, o resultado de roubo não existe.
    expect(find.text('Consta registro de roubo/furto'), findsNothing);

    // Rola até o botão "Consultar" da seção Roubo / furto e toca nele.
    final botaoRoubo = find.widgetWithText(FilledButton, 'Consultar').last;
    await tester.ensureVisible(botaoRoubo);
    await tester.pump();
    await tester.tap(botaoRoubo);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Consta registro de roubo/furto'), findsOneWidget);
  });

  group('Validação de placa', () {
    test('Aceita padrão antigo e Mercosul', () {
      expect(VehicleController.isValidPlate('ABC-1234'), isTrue);
      expect(VehicleController.isValidPlate('ABC1234'), isTrue);
      expect(VehicleController.isValidPlate('ABC1D23'), isTrue);
    });

    test('Rejeita placas com formato inválido', () {
      expect(VehicleController.isValidPlate('AB123'), isFalse);
      expect(VehicleController.isValidPlate('12345678'), isFalse);
      expect(VehicleController.isValidPlate(''), isFalse);
    });
  });
}
