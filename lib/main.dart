import 'package:flutter/material.dart';

import 'controllers/vehicle_controller.dart';
import 'repositories/vehicle_repository.dart';
import 'screens/vehicle_screen.dart';

void main() {
  // ===========================================================================
  // INJEÇÃO DE DEPENDÊNCIA — alterne entre MODO SIMULADO e MODO REAL aqui.
  // ===========================================================================
  //
  // As credenciais NÃO ficam hardcoded no código (evita vazar no git/binário).
  // Elas vêm de --dart-define em tempo de build. Veja env.json.example.
  //
  // 👉 MODO REAL: rode com
  //    flutter run --dart-define-from-file=env.json
  //
  // 👉 MODO SIMULADO (ativo sempre que as defines estiverem vazias): não
  //    consome saldo da API. Placas de teste: AAA1A11 (regular) e
  //    BBB2B22 (com restrição + roubo).
  //
  const String meuEmail = String.fromEnvironment('PLACA_API_EMAIL');
  const String minhaApiKey = String.fromEnvironment('PLACA_API_KEY');

  final VehicleRepository repository =
      meuEmail.isEmpty || minhaApiKey.isEmpty
          ? MockVehicleRepository()
          : HttpVehicleRepository(email: meuEmail, apiKey: minhaApiKey);
  //
  // ===========================================================================

  // O controller recebe o repositório escolhido acima. A tela não sabe (nem
  // precisa saber) se está falando com o Mock ou com a API real.
  final controller = VehicleController(repository);

  // Placas de exemplo: só mostramos as dicas quando estamos no modo Mock.
  final exemplos = repository is MockVehicleRepository
      ? MockVehicleRepository.exemplos
      : <String>[];

  runApp(PlacaCheckApp(controller: controller, exemplos: exemplos));
}

class PlacaCheckApp extends StatelessWidget {
  final VehicleController controller;
  final List<String> exemplos;

  const PlacaCheckApp({
    super.key,
    required this.controller,
    this.exemplos = const [],
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlacaCheck',
      debugShowCheckedModeBanner: false,
      // Tema claro com Material Design 3 habilitado e cor-semente.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
      ),
      // Tema escuro acompanhando a mesma semente.
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: VehicleScreen(controller: controller, exemplos: exemplos),
    );
  }
}
