import 'package:flutter_test/flutter_test.dart';
import 'package:bcam/services/diagnostic_logger_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DiagnosticLoggerService Tests', () {
    test('Logs are created with correct levels and categories', () {
      final logger = DiagnosticLoggerService.instance;
      logger.clearLogs();

      logger.logInfo('TEST', 'Teste de mensagem informativa');
      logger.logWarn('TEST_WARN', 'Teste de aviso importante');
      logger.logError('TEST_ERR', 'Teste de erro com detalhes', details: 'Detalhes adicionais de debug');

      expect(logger.entries.length, 3);
      expect(logger.entries[0].level, LogLevel.info);
      expect(logger.entries[0].message, 'Teste de mensagem informativa');

      expect(logger.entries[1].level, LogLevel.warn);
      expect(logger.entries[1].category, 'TEST_WARN');

      expect(logger.entries[2].level, LogLevel.error);
      expect(logger.entries[2].details, contains('Detalhes adicionais'));

      final fullLog = logger.getFullLogText();
      expect(fullLog, contains('[INFO] [TEST]'));
      expect(fullLog, contains('[WARN] [TEST_WARN]'));
      expect(fullLog, contains('[ERROR] [TEST_ERR]'));
    });

    test('clearLogs resets log buffer', () async {
      final logger = DiagnosticLoggerService.instance;
      logger.logInfo('TEST', 'Mensagem temporária');
      expect(logger.entries.isNotEmpty, isTrue);

      await logger.clearLogs();
      expect(logger.entries.isEmpty, isTrue);
    });
  });
}
