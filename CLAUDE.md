# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Sobre o projeto

PlacaCheck é um app Flutter (Android/iOS) para **consulta de veículos por placa** usando a **API Placas** da WD Desenvolvimento (`https://wdapi2.com.br`). O usuário digita uma placa e recebe dados do veículo (marca, modelo, ano, cor, chassi, motor, município/UF e situação legal).

Comunicação e comentários no código são em **português**.

## Comandos

```bash
flutter pub get          # instala dependências
flutter run              # roda o app em device/emulador
flutter analyze          # linter estático (deve passar sem issues)
flutter test             # roda todos os testes
flutter test test/widget_test.dart --plain-name "Validação de placa"  # roda um grupo/teste específico
```

## Arquitetura

Arquitetura limpa em camadas com dependência apontando sempre para abstrações. A regra central: a UI e o `VehicleController` dependem **apenas** da interface `VehicleRepository`, nunca de uma implementação concreta. É isso que permite alternar entre dados simulados e reais mudando uma única linha.

Fluxo: `VehicleScreen` → `VehicleController` (estado) → `VehicleRepository` (interface) → `MockVehicleRepository` **ou** `HttpVehicleRepository` → `VehicleModel`.

- **`lib/models/vehicle_model.dart`** — `VehicleModel` imutável + `fromJson`. O parsing é **deliberadamente defensivo**: a API Placas mistura chaves MAIÚSCULAS (`MARCA`, `MODELO`) com minúsculas (`ano`, `cor`) e guarda alguns campos num objeto aninhado `extra` (ano de fabricação, motor). O helper interno `pick()` tenta múltiplas chaves possíveis e cai num fallback em vez de quebrar. Se for ajustar campos, mantenha essa tolerância. O getter `isRegular` interpreta o texto livre de `situacao` para decidir regular vs. restrição.

- **`lib/repositories/vehicle_repository.dart`** — Contém a interface, as duas implementações e a `VehicleException` (erros de domínio com mensagem pronta para a UI). `MockVehicleRepository` simula latência com `Future.delayed` e só retorna dados para a placa de teste `ABC1D23` (qualquer outra placa válida simula "não encontrado", permitindo testar o fluxo de erro sem custo). `HttpVehicleRepository` chama `GET /consulta/{PLACA}/{TOKEN}`, trata status HTTP (401/402/404/429) **e** erros internos sinalizados dentro de um JSON 200.

- **`lib/controllers/vehicle_controller.dart`** — `ChangeNotifier` com a máquina de estados `VehicleStatus` (`inicial`/`carregando`/`sucesso`/`erro`). **Valida o formato da placa por Regex ANTES de chamar o repositório** — isso evita gastar saldo da API com placas malformadas. `isValidPlate` é estático e reutilizado pelos testes. Aceita padrão antigo (`ABC1234`) e Mercosul (`ABC1D23`); normaliza removendo hífens/espaços e forçando maiúsculas.

- **`lib/screens/vehicle_screen.dart`** — UI estritamente Material 3: cores sempre do `ColorScheme`/`TextTheme` do contexto (nunca cores hardcoded, exceto o verde semântico do chip "Regular", que não existe no ColorScheme padrão). Escuta o controller via listener e reconstrói com `setState`.

- **`lib/main.dart`** — **Ponto único de troca Mock ↔ Real.** As credenciais (`PLACA_API_EMAIL`, `PLACA_API_KEY`) vêm de `--dart-define`, nunca hardcoded no código. Sem elas, cai automaticamente em `MockVehicleRepository` (sem custo). Para usar a API real: `flutter run --dart-define-from-file=env.json`, com `env.json` criado a partir de `env.json.example` (o arquivo real é gitignored).

## Convenções importantes

- **Alternar Mock/Real é só em `main.dart`** — nunca espalhe a escolha do repositório por outras camadas.
- **Validar antes de consultar** — qualquer novo caminho que dispare consulta deve passar pela validação do controller para não desperdiçar saldo da API.
- **Erros viram `VehicleException`** — repositórios não devem vazar exceções de rede/parse cruas; convertem tudo para `VehicleException` com mensagem amigável que a UI exibe direto.
- **Credenciais da API nunca vão para o código-fonte nem para o git** — são passadas via `--dart-define-from-file=env.json` (arquivo gitignored, veja `env.json.example`). Mesmo assim, chaves embarcadas em apps mobile são extraíveis do binário — para produção, intermediar com um backend-proxy.
- **Permissão `INTERNET`** já está no `AndroidManifest.xml` principal (necessária no modo real, inclusive em release).
