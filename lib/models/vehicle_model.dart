/// Modelo de dados principal de um veículo (API Consultar Placa).
class VehicleModel {
  final String marca;
  final String modelo;
  final String anoFabricacao;
  final String anoModelo;
  final String cor;
  final String chassi;
  final String numeroMotor;
  final String situacao;
  final String municipio;
  final String uf;

  const VehicleModel({
    required this.marca,
    required this.modelo,
    required this.anoFabricacao,
    required this.anoModelo,
    required this.cor,
    required this.chassi,
    required this.numeroMotor,
    required this.situacao,
    required this.municipio,
    required this.uf,
  });

  /// true quando situacao não contém palavras que indiquem restrição.
  bool get isRegular {
    final s = situacao.toLowerCase();
    if (s == 'não informado' || s.isEmpty) return true;
    const restricoes = ['restrição', 'bloqueado', 'inativo', 'irregular', 'apreendido'];
    return !restricoes.any(s.contains);
  }

  /// Cria um [VehicleModel] a partir do JSON da API Consultar Placa.
  ///
  /// O parsing é defensivo: a API mistura chaves MAIÚSCULAS com minúsculas e
  /// guarda alguns campos em objetos aninhados. O helper [pick] tenta múltiplas
  /// chaves e usa um fallback em vez de lançar exceção.
  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    String pick(List<String> keys, {String fallback = 'Não informado'}) {
      for (final key in keys) {
        final v = _find(json, key);
        if (v != null && v.toString().trim().isNotEmpty) {
          return v.toString().trim();
        }
      }
      return fallback;
    }

    return VehicleModel(
      marca: pick(['marca', 'MARCA']),
      modelo: pick(['modelo', 'MODELO']),
      anoFabricacao: pick(['ano_fabricacao', 'ano_frabricacao', 'anoFabricacao']),
      anoModelo: pick(['ano_modelo', 'anoModelo', 'ano']),
      cor: pick(['cor', 'COR']),
      chassi: pick(['chassi', 'CHASSI']),
      numeroMotor: pick(['numero_motor', 'numeroMotor', 'motor']),
      situacao: pick(['situacao', 'situação', 'SITUACAO', 'situacao_veiculo']),
      municipio: pick(['municipio', 'município', 'MUNICIPIO', 'municipio_emplacamento']),
      // A API retorna 'uf_municipio' — mantemos fallbacks para outras APIs.
      uf: pick(['uf_municipio', 'uf', 'UF', 'uf_emplacamento']),
    );
  }

  /// Varredura recursiva: primeiro valor associado a [key] em qualquer
  /// profundidade de [node] (Map ou List). Null se não achar.
  static dynamic _find(dynamic node, String key) {
    if (node is Map) {
      if (node.containsKey(key)) return node[key];
      for (final v in node.values) {
        final r = _find(v, key);
        if (r != null) return r;
      }
    } else if (node is List) {
      for (final v in node) {
        final r = _find(v, key);
        if (r != null) return r;
      }
    }
    return null;
  }
}

/// Resultado de uma consulta opcional feita sob demanda (roubo/furto).
///
/// [valor] é o texto a exibir; [alerta] indica se deve ser destacado como
/// problema (vermelho) — ex.: roubo/furto encontrado.
class OptionalCheck {
  final String valor;
  final bool alerta;

  const OptionalCheck({required this.valor, this.alerta = false});
}
