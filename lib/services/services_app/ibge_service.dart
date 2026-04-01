// lib/services/services_app/ibge_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class EstadoIBGE {
  final int id;
  final String sigla;
  final String nome;

  const EstadoIBGE({
    required this.id,
    required this.sigla,
    required this.nome,
  });

  factory EstadoIBGE.fromJson(Map<String, dynamic> json) => EstadoIBGE(
        id: json['id'] as int,
        sigla: json['sigla'] as String,
        nome: json['nome'] as String,
      );

  @override
  String toString() => nome;
}

class CidadeIBGE {
  final int id;
  final String nome;

  const CidadeIBGE({required this.id, required this.nome});

  factory CidadeIBGE.fromJson(Map<String, dynamic> json) => CidadeIBGE(
        id: json['id'] as int,
        nome: json['nome'] as String,
      );

  @override
  String toString() => nome;
}

class IbgeService {
  static const _base = 'https://servicodados.ibge.gov.br/api/v1/localidades';

  // Cache em memória para evitar requisições repetidas
  static List<EstadoIBGE>? _estadosCache;
  static final Map<int, List<CidadeIBGE>> _cidadesCache = {};

  /// Busca todos os estados ordenados por nome
  Future<List<EstadoIBGE>> buscarEstados() async {
    if (_estadosCache != null) return _estadosCache!;

    final response =
        await http.get(Uri.parse('$_base/estados?orderBy=nome'));

    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar estados: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body) as List;
    _estadosCache = data
        .map((e) => EstadoIBGE.fromJson(e as Map<String, dynamic>))
        .toList();

    return _estadosCache!;
  }

  /// Busca municípios de um estado pelo ID da UF, ordenados por nome
  Future<List<CidadeIBGE>> buscarCidades(int estadoId) async {
    if (_cidadesCache.containsKey(estadoId)) {
      return _cidadesCache[estadoId]!;
    }

    final response = await http.get(
      Uri.parse('$_base/estados/$estadoId/municipios?orderBy=nome'),
    );

    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar cidades: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body) as List;
    final cidades = data
        .map((e) => CidadeIBGE.fromJson(e as Map<String, dynamic>))
        .toList();

    _cidadesCache[estadoId] = cidades;
    return cidades;
  }
}