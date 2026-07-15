import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/vehicle_model.dart';

/// Exceção de domínio usada para mensagens de erro amigáveis na UI.
class VehicleException implements Exception {
  final String message;
  const VehicleException(this.message);

  @override
  String toString() => message;
}

/// Contrato da camada de dados. A UI/Controller depende apenas desta abstração.
///
/// [getVehicle] é a consulta principal (dados cadastrais).
/// [consultarRoubo] é consulta OPCIONAL sob demanda.
abstract class VehicleRepository {
  Future<VehicleModel> getVehicle(String plate);
  Future<OptionalCheck> consultarRoubo(String plate);
  Future<OptionalCheck> consultarRenavam(String plate);
}

/// Dados internos do Mock por placa: o veículo principal + os valores das
/// consultas opcionais (roubo/furto).
class _MockData {
  final VehicleModel veiculo;
  final bool temRoubo;
  final String renavam;

  const _MockData({
    required this.veiculo,
    required this.temRoubo,
    required this.renavam,
  });
}

/// Implementação SIMULADA (Mock). Não faz rede, não consome saldo.
class MockVehicleRepository implements VehicleRepository {
  static const Map<String, _MockData> _catalogo = {
    // CENÁRIO 1 — Carro sem alerta de roubo na consulta opcional.
    'AAA1A11': _MockData(
      temRoubo: false,
      renavam: '12345678901',
      veiculo: VehicleModel(
        marca: 'Honda',
        modelo: 'Civic',
        anoFabricacao: '2019',
        anoModelo: '2020',
        cor: 'Cinza',
        chassi: '93HFC2670LZ207788',
        numeroMotor: 'R20A98765',
        situacao: 'Regular',
        municipio: 'São Paulo',
        uf: 'SP',
      ),
    ),
    // CENÁRIO 2 — Carro com alerta de ROUBO/FURTO na consulta opcional.
    'BBB2B22': _MockData(
      temRoubo: true,
      renavam: '98765432109',
      veiculo: VehicleModel(
        marca: 'Volkswagen',
        modelo: 'Gol',
        anoFabricacao: '2017',
        anoModelo: '2018',
        cor: 'Branco',
        chassi: '9BWZZZ377VT004251',
        numeroMotor: 'CWS123456',
        situacao: 'Com restrição',
        municipio: 'Rio de Janeiro',
        uf: 'RJ',
      ),
    ),
  };

  /// Placas de exemplo disponíveis no Mock (úteis para a tela exibir como dica).
  static List<String> get exemplos => _catalogo.keys.toList();

  // Fix #9: strips espaços E hífens — consistente com VehicleController.
  String _normalizar(String plate) =>
      plate.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  _MockData _buscar(String plate) {
    final data = _catalogo[_normalizar(plate)];
    if (data == null) {
      throw const VehicleException(
        'Veículo não encontrado para a placa informada (modo simulado).',
      );
    }
    return data;
  }

  @override
  Future<VehicleModel> getVehicle(String plate) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _buscar(plate).veiculo;
  }

  @override
  Future<OptionalCheck> consultarRoubo(String plate) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final tem = _buscar(plate).temRoubo;
    return OptionalCheck(
      valor: tem ? 'Consta registro de roubo/furto' : 'Nada consta',
      alerta: tem,
    );
  }

  @override
  Future<OptionalCheck> consultarRenavam(String plate) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return OptionalCheck(valor: _buscar(plate).renavam);
  }
}

/// Implementação REAL via HTTP contra a **API Consultar Placa**.
///
/// Autenticação: **Basic Auth** — `username` = e-mail da conta e
/// `password` = api_key, codificados em Base64 no header `Authorization`.
///
/// ⚠️ Segurança: e-mail e api_key embarcados no app são extraíveis. Em
/// produção, use um backend-proxy e nunca exponha as credenciais no cliente.
class HttpVehicleRepository implements VehicleRepository {
  static const String _baseUrl = 'https://api.consultarplaca.com.br';

  final String email;
  final String apiKey;
  final http.Client _client;

  HttpVehicleRepository({
    required this.email,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  // Fix #7: expõe dispose para fechar o pool de conexões quando o repositório
  // for descartado.
  void dispose() => _client.close();

  Map<String, String> get _headers => {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$email:$apiKey'))}',
        'Accept': 'application/json',
      };

  // Fix #9: strips espaços E hífens.
  String _normalizar(String plate) =>
      plate.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  /// Faz o GET, trata status codes e devolve o corpo JSON decodificado.
  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    http.Response response;
    try {
      response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const VehicleException(
        'Falha de conexão. Verifique sua internet e tente novamente.',
      );
    }

    switch (response.statusCode) {
      case 200:
        break;
      case 400:
        throw const VehicleException(
          'Requisição incorreta. Verifique a placa informada.',
        );
      case 401:
      case 403:
        throw const VehicleException(
          'Credenciais inválidas. Confira o e-mail e a API key (Basic Auth).',
        );
      case 402:
        throw const VehicleException(
          'Saldo/limite do plano esgotado na Consultar Placa.',
        );
      case 404:
      case 406:
        throw const VehicleException(
          'Nenhum resultado encontrado para esta placa.',
        );
      case 429:
        throw const VehicleException(
          'Limite de consultas atingido. Tente novamente mais tarde.',
        );
      default:
        throw VehicleException(
          'Erro inesperado na consulta (código ${response.statusCode}).',
        );
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const VehicleException(
        'Resposta inválida do servidor. Tente novamente mais tarde.',
      );
    }

    final status = data['status']?.toString().toLowerCase();
    // Aceita qualquer valor que indique sucesso; lança só quando é claramente erro.
    const statusErro = {'error', 'fail', 'failed', 'false', '0'};
    if (status != null && statusErro.contains(status)) {
      throw VehicleException(
        (data['mensagem'] ?? data['message'] ?? data['error'] ??
                'Não foi possível consultar esta placa.')
            .toString(),
      );
    }
    return data;
  }

  @override
  Future<VehicleModel> getVehicle(String plate) async {
    final uri = Uri.parse(
      '$_baseUrl/v2/consultarPlaca?placa=${_normalizar(plate)}',
    );
    return VehicleModel.fromJson(await _getJson(uri));
  }

  @override
  Future<OptionalCheck> consultarRoubo(String plate) async {
    final uri = Uri.parse(
      '$_baseUrl/v2/consultarHistoricoRouboFurto?placa=${_normalizar(plate)}',
    );
    final data = await _getJson(uri);
    final possui = _buscarChave(data, 'possui_registro')?.toLowerCase();

    if (possui == 'indisponivel') {
      return const OptionalCheck(valor: 'Informação indisponível no momento');
    }
    final tem = possui == 'sim';
    return OptionalCheck(
      valor: tem ? 'Consta registro de roubo/furto' : 'Nada consta',
      alerta: tem,
    );
  }

  @override
  Future<OptionalCheck> consultarRenavam(String plate) async {
    final uri = Uri.parse(
      '$_baseUrl/v2/consultarRenavam?placa=${_normalizar(plate)}',
    );
    final data = await _getJson(uri);
    final renavam = _buscarChave(data, 'renavam') ??
        _buscarChave(data, 'RENAVAM') ??
        _buscarChave(data, 'numero_renavam');
    if (renavam == null) {
      return const OptionalCheck(valor: 'RENAVAM não disponível');
    }
    return OptionalCheck(valor: renavam);
  }

  /// Busca recursiva de uma chave string no JSON.
  String? _buscarChave(dynamic node, String key) {
    final v = _buscar(node, key);
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static dynamic _buscar(dynamic node, String key) {
    if (node is Map) {
      if (node.containsKey(key)) return node[key];
      for (final v in node.values) {
        final r = _buscar(v, key);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final v in node) {
        final r = _buscar(v, key);
        if (r != null) return r;
      }
    }
    return null;
  }
}
