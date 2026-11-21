import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/app_update_service.dart';
import '../services/diagnostic_logger_service.dart';
import '../theme/fluent_theme.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _selectedFilter = 'TODOS';
  bool _autoScroll = true;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _copyAllLogs(DiagnosticLoggerService logger) async {
    final text = logger.getFullLogText();
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Logs Copiados'),
          content: Text('${logger.entries.length} linhas de log copiadas para a área de transferência!'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  Future<void> _clearLogs(DiagnosticLoggerService logger) async {
    await logger.clearLogs();
    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Logs Limpos'),
          content: const Text('Histórico de diagnóstico reiniciado.'),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
    }
  }

  Future<void> _sendToWhatsApp(DiagnosticLoggerService logger) async {
    final success = await logger.sendLogViaWhatsApp(phone: '5547988366727');
    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text(success ? 'WhatsApp Acionado' : 'Aviso'),
          content: Text(
            success
                ? 'Abrindo o WhatsApp com o arquivo de log para 47 98836-6727...'
                : 'Não foi possível acionar o WhatsApp diretamente no aparelho.',
          ),
          severity: success ? InfoBarSeverity.success : InfoBarSeverity.warning,
          onClose: close,
        ),
      );
    }
  }

  Future<void> _sendToHostMac(DiagnosticLoggerService logger) async {
    final success = await logger.sendLogsToHostMac();
    if (mounted) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text(success ? 'Logs Transmitidos' : 'Falha na Transmissão'),
          content: Text(
            success
                ? 'Os dados de depuração foram entregues ao Mac (192.168.3.62) com sucesso!'
                : 'Não foi possível alcançar o coletor no Mac em 192.168.3.62:8088. Use "Copiar" ou o endpoint HTTP.',
          ),
          severity: success ? InfoBarSeverity.success : InfoBarSeverity.error,
          onClose: close,
        ),
      );
    }
  }

  Future<void> _checkAndShowUpdateDialog() async {
    final updateService = AppUpdateService.instance;
    final info = await updateService.checkForUpdates();

    if (!mounted) return;

    if (info == null) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Servidor Indisponível'),
          content: Text('Não foi possível verificar atualizações no servidor ${updateService.updateServerUrl}.'),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
      return;
    }

    if (!info.hasUpdate) {
      displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: const Text('Aplicativo Atualizado'),
          content: Text('Você já está na versão mais recente (v${info.currentVersionName} • Build ${info.currentVersionCode}).'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
      return;
    }

    // Modal de Atualização In-App
    showDialog(
      context: context,
      builder: (context) {
        bool downloading = false;
        double progress = 0.0;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return ContentDialog(
              title: Row(
                children: [
                  const Icon(FluentIcons.cloud_download, color: BCamTheme.accentLightBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Nova Versão: v${info.remoteVersionName}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Versão Atual: v${info.currentVersionName} (Build ${info.currentVersionCode})\n'
                    'Nova Versão: v${info.remoteVersionName} (Build ${info.remoteVersionCode})',
                    style: GoogleFonts.robotoMono(fontSize: 12, color: BCamTheme.accentLightBlue),
                  ),
                  const SizedBox(height: 10),
                  Text('Novidades:', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(info.releaseNotes, style: GoogleFonts.inter(fontSize: 12, height: 1.3)),
                  const SizedBox(height: 14),
                  if (downloading) ...[
                    ProgressBar(value: progress * 100),
                    const SizedBox(height: 6),
                    Text(
                      'Baixando atualização: ${(progress * 100).toInt()}% ${info.fileSizeFormatted}',
                      style: GoogleFonts.robotoMono(fontSize: 11, color: BCamTheme.accentLightBlue),
                    ),
                  ],
                ],
              ),
              actions: [
                if (!downloading)
                  Button(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Mais Tarde'),
                  ),
                FilledButton(
                  onPressed: downloading
                      ? null
                      : () async {
                          setModalState(() => downloading = true);
                          await updateService.downloadAndInstallUpdate(
                            info,
                            onProgress: (p) => setModalState(() => progress = p),
                          );
                          if (context.mounted) Navigator.of(context).pop();
                        },
                  child: Text(downloading ? 'Baixando...' : 'Baixar e Atualizar Agora'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<LogEntry> _filterLogs(List<LogEntry> logs) {
    final query = _searchController.text.trim().toLowerCase();
    return logs.where((entry) {
      // Category filter
      if (_selectedFilter == 'ERROS' && entry.level != LogLevel.error) return false;
      if (_selectedFilter == 'RTSP' && !entry.category.contains('RTSP')) return false;
      if (_selectedFilter == 'REDE' && !entry.category.contains('SCANNER') && !entry.category.contains('DHCP')) return false;

      // Query filter
      if (query.isNotEmpty) {
        final inMsg = entry.message.toLowerCase().contains(query);
        final inCat = entry.category.toLowerCase().contains(query);
        final inDet = (entry.details ?? '').toLowerCase().contains(query);
        if (!inMsg && !inCat && !inDet) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final logger = DiagnosticLoggerService.instance;

    return ListenableBuilder(
      listenable: logger,
      builder: (context, _) {
        final filteredLogs = _filterLogs(logger.entries);
        _scrollToBottom();

        return SafeArea(
          child: ScaffoldPage(
            header: PageHeader(
              title: Row(
                children: [
                  IconButton(
                    icon: const Icon(FluentIcons.back, size: 16),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Logs',
                      style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              commandBar: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(FluentIcons.copy, size: 15),
                    onPressed: () => _copyAllLogs(logger),
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(FluentIcons.delete, size: 15),
                    onPressed: () => _clearLogs(logger),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(const Color(0xFF25D366)),
                    ),
                    onPressed: () => _sendToWhatsApp(logger),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FluentIcons.send, size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'WhatsApp',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Button(
                    onPressed: () => _sendToHostMac(logger),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FluentIcons.sync, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          'Mac',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            content: Column(
              children: [
                // Corporate Identity, Domain & Package Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Card(
                    backgroundColor: BCamTheme.darkSurface,
                    borderColor: BCamTheme.darkBorder,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: BCamTheme.accentBlue.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: BCamTheme.accentBlue.withValues(alpha: 0.5), width: 0.8),
                          ),
                          child: const Icon(FluentIcons.shield, size: 18, color: BCamTheme.accentLightBlue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'b-cam PRO',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: BCamTheme.accentBlue.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: BCamTheme.accentBlue.withValues(alpha: 0.6), width: 0.8),
                                    ),
                                    child: Text(
                                      'Powered by Bilk Sistemas',
                                      style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w700, color: BCamTheme.accentLightBlue),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Pacote: com.nexeoo.bcam • Domínio: bcam.nexeoo.com',
                                style: GoogleFonts.robotoMono(fontSize: 9.5, color: BCamTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Network Endpoint Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Card(
                    backgroundColor: BCamTheme.darkSurface,
                    borderColor: BCamTheme.darkBorder,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: BCamTheme.statusOnlineGlow,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Servidor HTTP de Diagnóstico Ativo',
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: BCamTheme.accentBlue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Porta ${DiagnosticLoggerService.diagnosticHttpPort}',
                                style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w700, color: BCamTheme.accentLightBlue),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Acesse os logs deste celular diretamente pelo seu navegador ou terminal:',
                          style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: BCamTheme.darkCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: BCamTheme.darkBorderSubtle),
                          ),
                          child: SelectableText(
                            'http://${logger.deviceIp}:${DiagnosticLoggerService.diagnosticHttpPort}/api/logs',
                            style: GoogleFonts.robotoMono(
                              fontSize: 11,
                              color: BCamTheme.accentLightBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Arquivo: ${logger.logFilePath ?? "Inicializando..."}',
                                style: GoogleFonts.inter(fontSize: 10, color: BCamTheme.textTertiary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${logger.entries.length} eventos registrados',
                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: BCamTheme.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // WhatsApp Log Delivery Card (Suporte 47 98836-6727)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Card(
                    backgroundColor: const Color(0xFF132018),
                    borderColor: const Color(0xFF1B4D2E),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0x3325D366),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF25D366), width: 0.8),
                              ),
                              child: const Icon(FluentIcons.chat, size: 16, color: Color(0xFF25D366)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Enviar Log via WhatsApp',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  Text(
                                    'Destinatário: 47 98836-6727 (Suporte Técnico)',
                                    style: GoogleFonts.robotoMono(fontSize: 10.5, color: const Color(0xFF25D366), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Anexa o arquivo b_cam_diagnostic.log e abre o WhatsApp do aparelho com a conversa pronta para envio:',
                          style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.all(const Color(0xFF25D366)),
                          ),
                          onPressed: () => _sendToWhatsApp(logger),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(FluentIcons.send, size: 13, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(
                                'Enviar Arquivo de Log para 47 98836-6727',
                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Remote Access & 3G/4G Architecture Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Card(
                    backgroundColor: BCamTheme.darkSurface,
                    borderColor: BCamTheme.darkBorder,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(FluentIcons.globe, size: 16, color: BCamTheme.accentLightBlue),
                                const SizedBox(width: 8),
                                Text(
                                  'Acesso Remoto (3G / 4G / Fora do Wi-Fi)',
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: BCamTheme.statusOnlineGlow.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '3G / 4G / 5G',
                                style: GoogleFonts.robotoMono(fontSize: 9.5, fontWeight: FontWeight.w700, color: BCamTheme.statusOnlineGlow),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Por padrão, IPs 192.168.3.x funcionam apenas no Wi-Fi local. Para acessar fora de casa, escolha uma das 2 opções:',
                          style: GoogleFonts.inter(fontSize: 11, color: BCamTheme.textSecondary, height: 1.3),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: BCamTheme.darkCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: BCamTheme.darkBorderSubtle),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'OPÇÃO 1: Seu Domínio nexeoo.com + Port Forwarding',
                                style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w700, color: BCamTheme.accentLightBlue),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Crie um subdomínio (ex: cameras.nexeoo.com) apontando para o seu IP público e redirecione as portas RTSP (8554, 8555) no roteador.',
                                style: GoogleFonts.inter(fontSize: 10.5, color: BCamTheme.textTertiary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'OPÇÃO 2 (Mais Segura): Tailscale / WireGuard VPN',
                                style: GoogleFonts.robotoMono(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF00E676)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Instale o Tailscale no celular e em um PC/servidor da casa. Conecta sem abrir portas e acessa os IPs locais em qualquer lugar do mundo.',
                                style: GoogleFonts.inter(fontSize: 10.5, color: BCamTheme.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // In-App Auto-Update Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Card(
                    backgroundColor: BCamTheme.darkSurface,
                    borderColor: BCamTheme.darkBorder,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: BCamTheme.accentBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(FluentIcons.cloud_download, size: 16, color: BCamTheme.accentLightBlue),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Atualização In-App (OTA)',
                                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: BCamTheme.textPrimary),
                                ),
                                Text(
                                  'Versão atual: v${AppUpdateService.appVersionName} • Build ${AppUpdateService.appVersionCode}',
                                  style: GoogleFonts.robotoMono(fontSize: 10.5, color: BCamTheme.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                        FilledButton(
                          onPressed: _checkAndShowUpdateDialog,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(FluentIcons.sync, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'Atualizar App',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search & Filter Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextBox(
                          controller: _searchController,
                          placeholder: 'Filtrar por texto, IP ou categoria...',
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(FluentIcons.search, size: 14, color: BCamTheme.textTertiary),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: () => setState(() => _autoScroll = !_autoScroll),
                        child: Icon(
                          _autoScroll ? FluentIcons.down : FluentIcons.pause,
                          size: 14,
                          color: _autoScroll ? BCamTheme.accentLightBlue : BCamTheme.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),

                // Category Pills
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['TODOS', 'ERROS', 'RTSP', 'REDE'].map((cat) {
                        final isSel = _selectedFilter == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Button(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.all(
                                isSel ? BCamTheme.accentBlue : BCamTheme.darkSurface,
                              ),
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  side: BorderSide(
                                    color: isSel ? BCamTheme.accentLightBlue : BCamTheme.darkBorder,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            onPressed: () => setState(() => _selectedFilter = cat),
                            child: Text(
                              cat,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                                color: isSel ? Colors.white : BCamTheme.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Log Records Stream List
                Expanded(
                  child: filteredLogs.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhum registro encontrado para o filtro atual.',
                            style: GoogleFonts.inter(fontSize: 13, color: BCamTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredLogs.length,
                          itemBuilder: (context, index) {
                            final log = filteredLogs[index];
                            final Color levelColor = switch (log.level) {
                              LogLevel.error => BCamTheme.statusOffline,
                              LogLevel.warn => BCamTheme.statusWarning,
                              LogLevel.info => BCamTheme.accentLightBlue,
                              LogLevel.debug => BCamTheme.textSecondary,
                            };

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: BCamTheme.darkSurface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: log.level == LogLevel.error
                                      ? BCamTheme.statusOffline.withValues(alpha: 0.5)
                                      : BCamTheme.darkBorderSubtle,
                                  width: log.level == LogLevel.error ? 1.0 : 0.6,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        log.timeFormatted,
                                        style: GoogleFonts.robotoMono(
                                          fontSize: 10,
                                          color: BCamTheme.textTertiary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: levelColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(3),
                                          border: Border.all(color: levelColor.withValues(alpha: 0.5), width: 0.8),
                                        ),
                                        child: Text(
                                          log.level.label,
                                          style: GoogleFonts.robotoMono(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: levelColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '[${log.category}]',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: BCamTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    log.message,
                                    style: GoogleFonts.inter(fontSize: 11.5, color: BCamTheme.textPrimary),
                                  ),
                                  if (log.details != null && log.details!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: BCamTheme.darkCard,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: BCamTheme.darkBorderSubtle),
                                      ),
                                      child: SelectableText(
                                        log.details!,
                                        style: GoogleFonts.robotoMono(
                                          fontSize: 10,
                                          color: log.level == LogLevel.error
                                              ? const Color(0xFFFF8888)
                                              : BCamTheme.accentLightBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
