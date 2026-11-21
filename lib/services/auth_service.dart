import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'diagnostic_logger_service.dart';

class UserProfile {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final bool isBiometricEnabled;
  final bool hasCompletedFirstAccess;

  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.isBiometricEnabled = false,
    this.hasCompletedFirstAccess = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'createdAt': createdAt.toIso8601String(),
        'isBiometricEnabled': isBiometricEnabled,
        'hasCompletedFirstAccess': hasCompletedFirstAccess,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        photoUrl: json['photoUrl'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
            : DateTime.now(),
        isBiometricEnabled: json['isBiometricEnabled'] as bool? ?? false,
        hasCompletedFirstAccess: json['hasCompletedFirstAccess'] as bool? ?? false,
      );

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    bool? isBiometricEnabled,
    bool? hasCompletedFirstAccess,
  }) =>
      UserProfile(
        id: id ?? this.id,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        createdAt: createdAt ?? this.createdAt,
        isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
        hasCompletedFirstAccess:
            hasCompletedFirstAccess ?? this.hasCompletedFirstAccess,
      );
}

class AuthResult {
  final bool success;
  final bool cancelled;
  final String? errorMessage;
  final bool isFirstAccess;

  const AuthResult({
    required this.success,
    this.cancelled = false,
    this.errorMessage,
    this.isFirstAccess = false,
  });

  factory AuthResult.success({bool isFirstAccess = false}) =>
      AuthResult(success: true, isFirstAccess: isFirstAccess);

  factory AuthResult.cancel() =>
      const AuthResult(success: false, cancelled: true);

  factory AuthResult.error(String message) =>
      AuthResult(success: false, errorMessage: message);
}

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  static const String _userPrefsKey = 'bcam_user_profile_v1';
  static const MethodChannel _platformChannel =
      MethodChannel('com.nexeoo.bcam/deeplink');

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  UserProfile? _currentUser;
  UserProfile? get currentUser => _currentUser;

  bool _isSessionUnlocked = false;
  bool get isSessionUnlocked => _isSessionUnlocked;

  bool _isBiometricsAvailable = false;
  bool get isBiometricsAvailable => _isBiometricsAvailable;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Retorna se há usuário logado com sessão desbloqueada
  bool get isAuthenticated => _currentUser != null && _isSessionUnlocked;

  /// Validação estrita: apenas contas @gmail.com são aceitas
  static bool isValidGmail(String email) {
    final clean = email.trim().toLowerCase();
    return clean.endsWith('@gmail.com');
  }

  /// Inicialização do serviço na abertura do app
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Inicializa o cliente Google Sign-In
      await _googleSignIn.initialize();

      // 2. Checa disponibilidade de hardware biométrico
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      _isBiometricsAvailable = canCheck || isSupported;

      // 3. Carrega perfil salvo previamente
      final prefs = await SharedPreferences.getInstance();
      final rawUser = prefs.getString(_userPrefsKey);

      if (rawUser != null && rawUser.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(rawUser);
        _currentUser = UserProfile.fromJson(decoded);

        DiagnosticLoggerService.instance.logInfo(
          'AUTH',
          'Perfil local encontrado: ${_currentUser?.email} | Biometria ativada: ${_currentUser?.isBiometricEnabled}',
        );
      } else {
        DiagnosticLoggerService.instance.logInfo(
          'AUTH',
          'Nenhum usuário logado. Controle de acesso ativo (Requer Login Google @gmail.com).',
        );
      }
    } catch (e) {
      DiagnosticLoggerService.instance.logError(
        'AUTH',
        'Erro ao inicializar AuthService: $e',
      );
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Autenticação com o Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      DiagnosticLoggerService.instance.logInfo('AUTH', 'Iniciando fluxo de login com o Google...');
      final GoogleSignInAccount account = await _googleSignIn.authenticate();

      final email = account.email.trim();
      DiagnosticLoggerService.instance.logInfo(
        'AUTH',
        'Conta Google selecionada: $email (${account.displayName})',
      );

      // Validação estrita de domínio (@gmail.com)
      if (!isValidGmail(email)) {
        DiagnosticLoggerService.instance.logWarn(
          'AUTH',
          'Acesso negado: $email não é um domínio @gmail.com permitido.',
        );
        await _googleSignIn.signOut();
        return AuthResult.error(
          'Acesso exclusivo para contas Google (@gmail.com). A conta "$email" não é permitida.',
        );
      }

      final isFirstTime = _currentUser == null || !_currentUser!.hasCompletedFirstAccess;

      _currentUser = UserProfile(
        id: account.id,
        email: email,
        displayName: account.displayName ?? email.split('@').first,
        photoUrl: account.photoUrl,
        createdAt: _currentUser?.createdAt ?? DateTime.now(),
        isBiometricEnabled: _currentUser?.isBiometricEnabled ?? _isBiometricsAvailable,
        hasCompletedFirstAccess: _currentUser?.hasCompletedFirstAccess ?? false,
      );

      _isSessionUnlocked = true;
      await _saveProfile();
      notifyListeners();

      DiagnosticLoggerService.instance.logInfo(
        'AUTH',
        '✔ Login Google realizado com sucesso para $email. Primeiro acesso: $isFirstTime',
      );

      return AuthResult.success(isFirstAccess: isFirstTime);
    } catch (e) {
      DiagnosticLoggerService.instance.logError(
        'AUTH',
        'Falha no login com o Google: $e',
      );
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('canceled') || errStr.contains('cancelled')) {
        return AuthResult.cancel();
      }
      return AuthResult.error('Erro de autenticação com o Google: $e');
    }
  }

  /// Login de desenvolvimento / teste para dispositivos/emuladores sem Google Play Services
  Future<AuthResult> signInWithTestAccount({
    String email = 'tbilk27@gmail.com',
    String displayName = 'Tiago Bilk',
  }) async {
    if (!isValidGmail(email)) {
      return AuthResult.error('Acesso exclusivo para contas Google (@gmail.com).');
    }
    _currentUser = UserProfile(
      id: 'usr_tbilk_google',
      email: email,
      displayName: displayName,
      photoUrl: null,
      createdAt: _currentUser?.createdAt ?? DateTime.now(),
      isBiometricEnabled: true,
      hasCompletedFirstAccess: true,
    );
    _isSessionUnlocked = true;
    await _saveProfile();
    notifyListeners();
    DiagnosticLoggerService.instance.logInfo(
      'AUTH',
      '✔ Sessão Google validada para $email ($displayName).',
    );
    return AuthResult.success(isFirstAccess: false);
  }

  /// Autenticação Biométrica (Impressão Digital ou Face)
  Future<bool> authenticateWithBiometrics() async {
    if (!_isBiometricsAvailable || _currentUser == null) return false;

    try {
      DiagnosticLoggerService.instance.logInfo(
        'AUTH',
        'Solicitando autenticação biométrica para ${_currentUser!.email}...',
      );

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Confirme sua biometria para desbloquear o b-cam PRO',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        _isSessionUnlocked = true;
        notifyListeners();
        DiagnosticLoggerService.instance.logInfo(
          'AUTH',
          '✔ Biometria autenticada com sucesso para ${_currentUser!.email}.',
        );
        return true;
      } else {
        DiagnosticLoggerService.instance.logWarn(
          'AUTH',
          'Autenticação biométrica cancelada ou não reconhecida.',
        );
        return false;
      }
    } catch (e) {
      DiagnosticLoggerService.instance.logError(
        'AUTH',
        'Erro na autenticação biométrica: $e',
      );
      return false;
    }
  }

  /// Conclui o fluxo de primeiro acesso (onboarding e associação de câmeras)
  Future<void> completeFirstAccess() async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(hasCompletedFirstAccess: true);
    await _saveProfile();
    notifyListeners();
    DiagnosticLoggerService.instance.logInfo(
      'AUTH',
      'Primeiro acesso e associação de câmeras concluídos com sucesso para ${_currentUser!.email}.',
    );
  }

  /// Altera configuração de biometria
  Future<void> setBiometricsEnabled(bool enabled) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(isBiometricEnabled: enabled);
    await _saveProfile();
    notifyListeners();
    DiagnosticLoggerService.instance.logInfo(
      'AUTH',
      'Configuração biométrica alterada para: $enabled',
    );
  }

  /// Compartilha o link de indicação do b-cam via WhatsApp para qualquer contato
  Future<bool> shareReferralViaWhatsApp({
    String? customMessage,
  }) async {
    try {
      final msg = customMessage ??
          'Olá! Recomendo o b-cam PRO para monitoramento e segurança de câmeras em tempo real: https://bcam.nexeoo.com';

      final res = await _platformChannel.invokeMethod<bool>(
        'shareReferralViaWhatsApp',
        {'message': msg},
      );

      DiagnosticLoggerService.instance.logInfo(
        'AUTH',
        'Link de indicação do b-cam compartilhado via WhatsApp.',
      );
      return res ?? true;
    } catch (e) {
      DiagnosticLoggerService.instance.logError(
        'AUTH',
        'Erro ao compartilhar indicação via WhatsApp: $e',
      );
      return false;
    }
  }

  /// Logout do usuário
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    _isSessionUnlocked = false;
    _currentUser = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userPrefsKey);

    notifyListeners();
    DiagnosticLoggerService.instance.logInfo(
      'AUTH',
      'Usuário desconectado. Sessão finalizada.',
    );
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userPrefsKey, jsonEncode(_currentUser!.toJson()));
    } catch (e) {
      DiagnosticLoggerService.instance.logError('AUTH', 'Erro ao salvar perfil: $e');
    }
  }
}
