# PlacaCheck

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](./LICENSE)

App Flutter (Android/iOS) para consulta de veículos por placa. O usuário digita uma placa (padrão antigo ou Mercosul) e recebe dados do veículo — marca, modelo, ano, cor, chassi, motor, município/UF e situação legal — via [API da Consultar Placa](https://consultarplaca.com.br).

> Uso pessoal deste app: os [termos de uso](https://www.consultarplaca.com.br/termos-de-uso/) da Consultar Placa proíbem redistribuir, divulgar ou revender os dados retornados pela API. Este repositório contém apenas o código-fonte do cliente — nenhum dado real de consulta é versionado.

## Funcionalidades

- Consulta de dados cadastrais por placa, com validação de formato (regex) antes de qualquer chamada à API.
- Suporte a placa padrão antigo (`ABC1234`) e Mercosul (`ABC1D23`).
- Consultas opcionais de roubo/furto e RENAVAM.
- Indicação visual de situação regular vs. restrição.
- UI Material 3, com tema claro/escuro seguindo o sistema.
- Modo simulado (mock) embutido, sem custo de API, para desenvolver e testar à vontade.

## Arquitetura

Arquitetura em camadas, com a UI e o `VehicleController` dependendo apenas da interface `VehicleRepository` — nunca de uma implementação concreta:

```
VehicleScreen → VehicleController (estado) → VehicleRepository (interface)
                                                 ├── MockVehicleRepository
                                                 └── HttpVehicleRepository
```

Mais detalhes de arquitetura e convenções do projeto estão em [`CLAUDE.md`](./CLAUDE.md).

## Como rodar

```bash
flutter pub get
```

### Modo simulado (padrão, sem custo de API)

```bash
flutter run
```

Placas de teste: `AAA1A11` (regular) e `BBB2B22` (com restrição + roubo).

### Modo real (consulta a API de verdade)

1. Crie uma conta na [Consultar Placa](https://consultarplaca.com.br) e obtenha seu e-mail + API key.
2. Copie `env.json.example` para `env.json` e preencha com suas credenciais:
   ```bash
   cp env.json.example env.json
   ```
3. Rode o app passando as credenciais em tempo de build:
   ```bash
   flutter run --dart-define-from-file=env.json
   ```

`env.json` está no `.gitignore` — suas credenciais nunca vão para o controle de versão.

## Testes e análise estática

```bash
flutter analyze   # linter estático, deve passar sem issues
flutter test      # suíte de testes
```

## Aviso de segurança

Credenciais embarcadas em apps mobile são extraíveis do binário. Este projeto é de uso pessoal; para produção, recomenda-se intermediar as chamadas à API com um backend-proxy em vez de expor a API key no cliente.

## Licença

Distribuído sob a licença [Apache 2.0](./LICENSE).
