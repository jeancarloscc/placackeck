import 'package:flutter/foundation.dart';

import '../models/vehicle_model.dart';
import '../repositories/vehicle_repository.dart';

/// Estados possíveis de uma consulta (principal ou opcional).
enum VehicleStatus { inicial, carregando, sucesso, erro }

/// Gerenciador de estado da tela de consulta de placas.
///
/// Controla a consulta principal e, separadamente, as consultas OPCIONAIS
/// (roubo/furto) feitas sob demanda por botões na tela. Depende apenas da
/// abstração [VehicleRepository].
class VehicleController extends ChangeNotifier {
  final VehicleRepository _repository;

  VehicleController(this._repository);

  // --- Consulta principal ---------------------------------------------------
  VehicleStatus _status = VehicleStatus.inicial;
  VehicleStatus get status => _status;

  VehicleModel? _vehicle;
  VehicleModel? get vehicle => _vehicle;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Placa da última consulta principal bem-sucedida (usada nas opcionais e para copiar).
  String? _placaAtual;
  String? get placaAtual => _placaAtual;

  bool get isLoading => _status == VehicleStatus.carregando;
  bool get hasResult => _status == VehicleStatus.sucesso && _vehicle != null;
  bool get hasError => _status == VehicleStatus.erro;

  // --- Consulta opcional (roubo/furto) --------------------------------------
  // Fix #5: campos privados com getters — mutação externa impossível sem
  // passar por notifyListeners().
  VehicleStatus _rouboStatus = VehicleStatus.inicial;
  VehicleStatus get rouboStatus => _rouboStatus;

  OptionalCheck? _rouboResult;
  OptionalCheck? get rouboResult => _rouboResult;

  String? _rouboErro;
  String? get rouboErro => _rouboErro;

  VehicleStatus _renavamStatus = VehicleStatus.inicial;
  VehicleStatus get renavamStatus => _renavamStatus;

  OptionalCheck? _renavamResult;
  OptionalCheck? get renavamResult => _renavamResult;

  String? _renavamErro;
  String? get renavamErro => _renavamErro;

  // Fix #2: contador de geração — cada nova busca principal incrementa este
  // valor, invalidando resultados de consultas opcionais ainda em voo.
  int _buscaId = 0;

  /// Regex que aceita os dois padrões brasileiros (após remover hífen/espaços):
  /// - Antigo:   ABC1234   (3 letras + 4 números)
  /// - Mercosul: ABC1D23   (3 letras + número + letra + 2 números)
  static final RegExp _plateRegex =
      RegExp(r'^[A-Z]{3}[0-9]{4}$|^[A-Z]{3}[0-9][A-Z][0-9]{2}$');

  // Fix #8: normaliza internamente — callers não precisam pré-normalizar.
  static bool isValidPlate(String plate) {
    final normalizada = plate.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    return _plateRegex.hasMatch(normalizada);
  }

  /// Dispara a consulta principal da [plate]. Valida o formato antes de chamar
  /// o repositório (evita gastar saldo da API com placas malformadas).
  Future<void> search(String plate) async {
    // Fix #8: valida a entrada bruta — isValidPlate cuida da normalização
    // internamente, sem duplicar a lógica aqui.
    if (!isValidPlate(plate)) {
      _status = VehicleStatus.erro;
      _vehicle = null;
      _errorMessage =
          'Placa inválida. Use o formato ABC-1234 ou ABC1D23 (Mercosul).';
      notifyListeners();
      return;
    }

    final normalizada = plate.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

    // Fix #2: incrementa antes do await — consultarRoubo() em voo vai
    // detectar que _buscaId mudou e descartar o resultado.
    _buscaId++;
    _resetOpcionais();
    _placaAtual = normalizada;
    _status = VehicleStatus.carregando;
    _vehicle = null;
    _errorMessage = null;
    notifyListeners();

    try {
      _vehicle = await _repository.getVehicle(normalizada);
      _status = VehicleStatus.sucesso;
    } on VehicleException catch (e) {
      _errorMessage = e.message;
      _status = VehicleStatus.erro;
    } catch (_) {
      _errorMessage = 'Ocorreu um erro inesperado. Tente novamente.';
      _status = VehicleStatus.erro;
    } finally {
      notifyListeners();
    }
  }

  /// Consulta opcional de roubo/furto (sob demanda).
  Future<void> consultarRoubo() async {
    if (_rouboStatus == VehicleStatus.carregando) return;
    final placa = _placaAtual;
    if (placa == null) return;

    // Fix #2: captura geração ANTES do await para comparar ao retornar.
    final buscaId = _buscaId;

    _rouboStatus = VehicleStatus.carregando;
    _rouboErro = null;
    notifyListeners();

    try {
      final result = await _repository.consultarRoubo(placa);
      // Fix #2: descarta se uma nova busca principal foi iniciada enquanto
      // esta requisição estava em voo.
      if (buscaId != _buscaId) return;
      _rouboResult = result;
      _rouboStatus = VehicleStatus.sucesso;
      notifyListeners();
    } on VehicleException catch (e) {
      if (buscaId != _buscaId) return;
      _rouboErro = e.message;
      _rouboStatus = VehicleStatus.erro;
      notifyListeners();
    } catch (_) {
      if (buscaId != _buscaId) return;
      _rouboErro = 'Não foi possível consultar roubo/furto.';
      _rouboStatus = VehicleStatus.erro;
      notifyListeners();
    }
  }

  Future<void> consultarRenavam() async {
    if (_renavamStatus == VehicleStatus.carregando) return;
    final placa = _placaAtual;
    if (placa == null) return;

    final buscaId = _buscaId;

    _renavamStatus = VehicleStatus.carregando;
    _renavamErro = null;
    notifyListeners();

    try {
      final result = await _repository.consultarRenavam(placa);
      if (buscaId != _buscaId) return;
      _renavamResult = result;
      _renavamStatus = VehicleStatus.sucesso;
      notifyListeners();
    } on VehicleException catch (e) {
      if (buscaId != _buscaId) return;
      _renavamErro = e.message;
      _renavamStatus = VehicleStatus.erro;
      notifyListeners();
    } catch (_) {
      if (buscaId != _buscaId) return;
      _renavamErro = 'Não foi possível consultar o RENAVAM.';
      _renavamStatus = VehicleStatus.erro;
      notifyListeners();
    }
  }

  void _resetOpcionais() {
    _rouboStatus = VehicleStatus.inicial;
    _rouboResult = null;
    _rouboErro = null;
    _renavamStatus = VehicleStatus.inicial;
    _renavamResult = null;
    _renavamErro = null;
  }

  /// Volta a tela ao estado inicial (limpa resultado, erro e opcionais).
  void reset() {
    _status = VehicleStatus.inicial;
    _vehicle = null;
    _errorMessage = null;
    _placaAtual = null;
    _resetOpcionais();
    notifyListeners();
  }
}
