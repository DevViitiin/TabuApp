// lib/routes/auth_guard.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tabuapp/screens/screens_auth/acess_code_screen/acess_code_screen.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/screens/screens_home/home_screen/home/location_permission_screen.dart';
import 'package:tabuapp/screens/screens_home/penalty_screen/penalty_screen.dart';
import 'package:tabuapp/widgets/main_navigation.dart';

class AuthGuard extends StatefulWidget {
  const AuthGuard({super.key});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  // null = checando | false = falta permissão | true = ok
  bool? _permissionsOk;
  bool _sessionLoading = true;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // 1. Checa todas as permissões necessárias
    final allOk = await _checkAllPermissions();

    if (!allOk) {
      if (mounted) setState(() { _permissionsOk = false; _sessionLoading = false; });
      return;
    }

    // 2. Checa auth
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() {
        _permissionsOk   = true;
        _sessionLoading  = false;
        _destination     = const AccessCodeScreen();
      });
      return;
    }

    // 3. Carrega sessão
    final destination = await _resolveDestination(user.uid);
    if (mounted) setState(() {
      _permissionsOk  = true;
      _sessionLoading = false;
      _destination    = destination;
    });
  }

  /// Retorna true somente se localização, câmera, microfone,
  /// notificações e galeria estiverem todos concedidos.
  Future<bool> _checkAllPermissions() async {
    // Localização
    final locPerm = await Geolocator.checkPermission();
    final locOk   = locPerm == LocationPermission.always ||
                    locPerm == LocationPermission.whileInUse;
    if (!locOk) return false;

    // Câmera e microfone
    final camOk = await Permission.camera.isGranted;
    final micOk = await Permission.microphone.isGranted;
    if (!camOk || !micOk) return false;

    // Notificações
    final notifOk = await Permission.notification.isGranted;
    if (!notifOk) return false;

    // Galeria — Android 13+ usa permissões granulares;
    // Android < 13 usa READ_EXTERNAL_STORAGE
    final galleryOk = await _isGalleryGranted();
    if (!galleryOk) return false;

    return true;
  }

  /// Verifica galeria de forma compatível entre versões do Android.
  Future<bool> _isGalleryGranted() async {
    final photosStatus = await Permission.photos.status;
    // Se não for permanentlyDenied, a API granular existe (Android 13+)
    if (photosStatus != PermissionStatus.permanentlyDenied &&
        photosStatus != PermissionStatus.denied) {
      final videosStatus = await Permission.videos.status;
      return photosStatus.isGranted && videosStatus.isGranted;
    }
    // Fallback para Android < 13
    return (await Permission.storage.status).isGranted;
  }

  Future<Widget> _resolveDestination(String uid) async {
    final results = await Future.wait([
      FirebaseDatabase.instance.ref('Users/$uid').get(),
      FirebaseDatabase.instance.ref('Administratives/$uid').get(),
    ]);

    final userSnap  = results[0];
    final adminSnap = results[1];

    Map<String, dynamic> userData;
    if (userSnap.exists && userSnap.value != null) {
      userData = _deepCast(userSnap.value as Map);
      userData['uid'] = uid;
    } else {
      final u = FirebaseAuth.instance.currentUser;
      userData = {
        'uid':   uid,
        'name':  u?.displayName ?? '',
        'email': u?.email ?? '',
      };
    }

    final isAdmin        = adminSnap.exists && adminSnap.value == true;
    final banido         = userData['banido']        as bool? ?? false;
    final suspenso       = userData['suspenso']      as bool? ?? false;
    final suspensaoFim   = userData['suspensao_fim'] as int?;
    final suspensaoAtiva = suspenso &&
        suspensaoFim != null &&
        suspensaoFim > DateTime.now().millisecondsSinceEpoch;

    if (banido)         return BanimentoScreen(userData: userData, uid: uid);
    if (suspensaoAtiva) return SuspensaoScreen(userData: userData, uid: uid);

    final List<_UnseenPenalty> unseen = [];
    final pens = userData['penalidades'];
    if (pens is Map) {
      for (final entry in pens.entries) {
        if (entry.value is! Map) continue;
        final p    = Map<String, dynamic>.from(entry.value as Map);
        final tipo = p['tipo']  as String? ?? '';
        final vista= p['vista'] as bool?   ?? false;
        if (!vista && (tipo == 'advertencia' || tipo == 'remover_conteudo')) {
          unseen.add(_UnseenPenalty(key: entry.key.toString(), penalidade: p));
        }
      }
      unseen.sort((a, b) =>
          (b.penalidade['aplicada_em'] as int? ?? 0)
          .compareTo(a.penalidade['aplicada_em'] as int? ?? 0));
    }

    if (unseen.isNotEmpty) {
      return AdvertenciaScreen(
        penalidade:    unseen.first.penalidade,
        penalidadeKey: unseen.first.key,
        uid:           uid,
        onOk: () async {
          final dest = await _resolveDestination(uid);
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => dest),
              (route) => false,
            );
          }
        },
      );
    }

    return TabuShell(userData: userData, isAdmin: isAdmin);
  }

  static Map<String, dynamic> _deepCast(Map raw) => raw.map((k, v) {
    final key = k?.toString() ?? '';
    dynamic value;
    if (v is Map)       value = _deepCast(v);
    else if (v is List) value = _castList(v);
    else                value = v;
    return MapEntry(key, value);
  });

  static List<dynamic> _castList(List list) => list.map((e) {
    if (e is Map)  return _deepCast(e);
    if (e is List) return _castList(e);
    return e;
  }).toList();

  @override
  Widget build(BuildContext context) {
    // Ainda carregando
    if (_sessionLoading || _permissionsOk == null) {
      return const _LoadingScreen();
    }

    // Falta alguma permissão — abre o fluxo de permissões
    if (!_permissionsOk!) {
      return LocationPermissionScreen(onContinue: () async {
        setState(() { _sessionLoading = true; _permissionsOk = null; });
        await _boot();
      });
    }

    return _destination ?? const _LoadingScreen();
  }
}

// ── Modelos ───────────────────────────────────────────────────────────────────
class _UnseenPenalty {
  final String               key;
  final Map<String, dynamic> penalidade;
  const _UnseenPenalty({required this.key, required this.penalidade});
}

// ── Loading Screen ────────────────────────────────────────────────────────────
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TabuColors.bg,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
                colors: [TabuColors.rosaPrincipal, TabuColors.rosaClaro])
                .createShader(b),
            child: const Text('TABU',
              style: TextStyle(
                fontFamily: TabuTypography.displayFont,
                fontSize: 36, letterSpacing: 10, color: Colors.white))),
          const SizedBox(height: 28),
          const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(
              color: TabuColors.rosaPrincipal, strokeWidth: 1.5)),
        ]),
      ),
    );
  }
}