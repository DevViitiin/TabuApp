// lib/models/party_model.dart

class PartyModel {
  final String   id;
  final String   creatorId;
  final String   creatorName;
  final String?  creatorAvatar;
  final String   nome;
  final String   descricao;

  /// Endereço do evento. Pode ser nulo quando ainda não confirmado pelo criador.
  final String?  local;

  final String?  bairro;
  final String?  city;
  final String?  state;
  final double?  latitude;
  final double?  longitude;
  final DateTime dataInicio;
  final DateTime dataFim;
  final String?  bannerUrl;
  final int      interessados;
  final int      confirmados;
  final int      commentCount;
  final DateTime createdAt;

  /// 'ativa' | 'arquivada'
  final String status;

  const PartyModel({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    this.creatorAvatar,
    required this.nome,
    required this.descricao,
    this.local,           // agora opcional
    this.bairro,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    required this.dataInicio,
    required this.dataFim,
    this.bannerUrl,
    this.interessados  = 0,
    this.confirmados   = 0,
    this.commentCount  = 0,
    required this.createdAt,
    this.status        = 'ativa',
  });

  bool get hasCoords      => latitude  != null && longitude != null;
  bool get isAtiva        => status == 'ativa';
  bool get isArquivada    => status == 'arquivada';
  bool get estaVencida    => DateTime.now().isAfter(dataFim);

  /// True quando o endereço foi informado (não nulo e não vazio).
  bool get hasLocal       => local != null && local!.trim().isNotEmpty;

  /// True quando há coordenadas E endereço confirmado — só então cabe calcular distância.
  bool get canShowDistance => hasCoords && hasLocal;

  factory PartyModel.fromMap(String id, Map<dynamic, dynamic> map) {
    // Lê o campo; aceita nulo, string vazia ou preenchida
    final localRaw = map['local'] as String?;

    return PartyModel(
      id:            id,
      creatorId:     map['creator_id']     as String,
      creatorName:   map['creator_name']   as String?  ?? '',
      creatorAvatar: map['creator_avatar'] as String?,
      nome:          map['nome']           as String?  ?? '',
      descricao:     map['descricao']      as String?  ?? '',
      local:         (localRaw != null && localRaw.trim().isNotEmpty)
                       ? localRaw
                       : null,
      bairro:        map['bairro']         as String?,
      city:          map['city']           as String?,
      state:         map['state']          as String?,
      latitude:      (map['latitude']      as num?)?.toDouble(),
      longitude:     (map['longitude']     as num?)?.toDouble(),
      dataInicio:    DateTime.fromMillisecondsSinceEpoch(map['data_inicio'] as int),
      dataFim:       DateTime.fromMillisecondsSinceEpoch(map['data_fim']    as int),
      bannerUrl:     map['banner_url']     as String?,
      interessados:  (map['interessados']  as num? ?? 0).toInt(),
      confirmados:   (map['confirmados']   as num? ?? 0).toInt(),
      commentCount:  (map['comment_count'] as num? ?? 0).toInt(),
      createdAt:     DateTime.fromMillisecondsSinceEpoch(map['created_at']  as int),
      status:        map['status'] as String? ?? 'ativa',
    );
  }

  Map<String, dynamic> toMap() => {
    'creator_id':     creatorId,
    'creator_name':   creatorName,
    if (creatorAvatar != null) 'creator_avatar': creatorAvatar,
    'nome':           nome,
    'descricao':      descricao,
    // Só grava o campo se tiver endereço; omite quando não confirmado
    if (hasLocal) 'local': local,
    if (bairro    != null) 'bairro':    bairro,
    if (city      != null) 'city':      city,
    if (state     != null) 'state':     state,
    if (latitude  != null) 'latitude':  latitude,
    if (longitude != null) 'longitude': longitude,
    'data_inicio':    dataInicio.millisecondsSinceEpoch,
    'data_fim':       dataFim.millisecondsSinceEpoch,
    if (bannerUrl != null) 'banner_url': bannerUrl,
    'interessados':   interessados,
    'confirmados':    confirmados,
    'comment_count':  commentCount,
    'created_at':     createdAt.millisecondsSinceEpoch,
    'status':         status,
  };

  PartyModel copyWith({String? status, String? local}) => PartyModel(
    id:            id,
    creatorId:     creatorId,
    creatorName:   creatorName,
    creatorAvatar: creatorAvatar,
    nome:          nome,
    descricao:     descricao,
    local:         local ?? this.local,
    bairro:        bairro,
    city:          city,
    state:         state,
    latitude:      latitude,
    longitude:     longitude,
    dataInicio:    dataInicio,
    dataFim:       dataFim,
    bannerUrl:     bannerUrl,
    interessados:  interessados,
    confirmados:   confirmados,
    commentCount:  commentCount,
    createdAt:     createdAt,
    status:        status ?? this.status,
  );
}

enum FestaPresenca { nenhuma, interessado, confirmado }