import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controllers/vehicle_controller.dart';
import '../models/vehicle_model.dart';

/// Tela principal de consulta de veículos por placa.
///
/// Toda a UI segue as diretrizes do Material Design 3: cores derivadas do
/// [ColorScheme] do tema, componentes M3 (FilledButton, Card, Chip, Badge) e
/// tipografia do [TextTheme].
class VehicleScreen extends StatefulWidget {
  /// Controller injetado (já criado com o repositório Mock ou HTTP no main).
  final VehicleController controller;

  /// Placas de exemplo exibidas como dicas clicáveis na tela inicial.
  /// Vazio no modo real; preenchido no modo Mock (ver [main]).
  final List<String> exemplos;

  const VehicleScreen({
    super.key,
    required this.controller,
    this.exemplos = const [],
  });

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final TextEditingController _plateController = TextEditingController();

  VehicleController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _plateController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onSearchPressed() {
    FocusScope.of(context).unfocus();
    _controller.search(_plateController.text);
  }

  /// Preenche o campo com uma placa de exemplo e já dispara a consulta.
  void _onExampleTap(String plate) {
    _plateController.text = plate;
    _onSearchPressed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: scheme.surfaceContainer,
        title: Text(
          'PlacaCheck',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchField(scheme, textTheme),
              const SizedBox(height: 16),
              _buildSearchButton(),
              const SizedBox(height: 24),
              _buildContent(scheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Campo de busca (TextField M3)
  // ---------------------------------------------------------------------------
  Widget _buildSearchField(ColorScheme scheme, TextTheme textTheme) {
    return TextField(
      controller: _plateController,
      enabled: !_controller.isLoading,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.search,
      maxLength: 8,
      style: textTheme.titleMedium?.copyWith(letterSpacing: 2),
      inputFormatters: [
        // Mantém apenas letras/números e força maiúsculas.
        FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
        TextInputFormatter.withFunction(
          (oldValue, newValue) => newValue.copyWith(
            text: newValue.text.toUpperCase(),
          ),
        ),
      ],
      onSubmitted: (_) => _onSearchPressed(),
      decoration: InputDecoration(
        labelText: 'Placa do veículo',
        hintText: 'ABC1D23',
        counterText: '',
        prefixIcon: const Icon(Icons.directions_car),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Botão de consulta (FilledButton M3)
  // ---------------------------------------------------------------------------
  Widget _buildSearchButton() {
    return FilledButton.icon(
      onPressed: _controller.isLoading ? null : _onSearchPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      icon: _controller.isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : const Icon(Icons.search),
      label: Text(_controller.isLoading ? 'Consultando...' : 'Consultar'),
    );
  }

  // ---------------------------------------------------------------------------
  // Área de conteúdo dinâmica (estados: inicial / loading / sucesso / erro)
  // ---------------------------------------------------------------------------
  Widget _buildContent(ColorScheme scheme, TextTheme textTheme) {
    switch (_controller.status) {
      case VehicleStatus.carregando:
        return Column(
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Buscando informações do veículo...',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        );

      case VehicleStatus.sucesso:
        return _ResultCard(controller: _controller);

      case VehicleStatus.erro:
        return _ErrorCard(message: _controller.errorMessage ?? 'Erro.');

      case VehicleStatus.inicial:
        return _EmptyState(
          scheme: scheme,
          textTheme: textTheme,
          exemplos: widget.exemplos,
          onExampleTap: _onExampleTap,
        );
    }
  }
}

// =============================================================================
// Estado inicial (placeholder amigável)
// =============================================================================
class _EmptyState extends StatelessWidget {
  final ColorScheme scheme;
  final TextTheme textTheme;
  final List<String> exemplos;
  final void Function(String plate) onExampleTap;

  const _EmptyState({
    required this.scheme,
    required this.textTheme,
    required this.exemplos,
    required this.onExampleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.search, size: 72, color: scheme.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'Digite uma placa para consultar',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),

          // Seção de placas de exemplo (apenas no modo Mock, para avaliação).
          if (exemplos.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              'Ou toque em uma placa de exemplo:',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final placa in exemplos)
                  ActionChip(
                    avatar: const Icon(Icons.directions_car, size: 18),
                    label: Text(placa),
                    onPressed: () => onExampleTap(placa),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Fix #6: verde semântico tema-aware — escuro no tema claro (contraste ok),
// claro no tema escuro (contraste ok). Não existe cor de "sucesso" no
// ColorScheme padrão do M3.
Color _corVerde(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? const Color(0xFF81C784) // green 300 — legível em fundo escuro
    : const Color(0xFF1B5E20); // green 900 — legível em fundo claro

// Fix #4: limpa SnackBars anteriores antes de exibir novo, evitando fila
// de notificações quando o usuário toca "copiar" várias vezes seguidas.
void _copiar(BuildContext context, String texto) {
  Clipboard.setData(ClipboardData(text: texto));
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      const SnackBar(
        content: Text('Copiado!'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

// =============================================================================
// Card de resultado (sucesso)
// =============================================================================
class _ResultCard extends StatelessWidget {
  final VehicleController controller;

  const _ResultCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final vehicle = controller.vehicle!;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho: marca + modelo, ano e cor.
            Text(
              '${vehicle.marca} ${vehicle.modelo}',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${vehicle.anoModelo} • ${vehicle.cor}',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            // Fix #3: chip de situação legal do veículo.
            _StatusChip(isRegular: vehicle.isRegular, situacao: vehicle.situacao),

            const Divider(height: 32),

            // Dados cadastrais — confira se batem com o carro à sua frente.
            Text(
              'Dados cadastrais',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            if (controller.placaAtual != null)
              _InfoTile(
                icon: Icons.pin,
                titulo: 'Placa',
                valor: controller.placaAtual!,
                copiavel: true,
              ),
            // Fix #3: município e UF agora exibidos na UI.
            _InfoTile(
              icon: Icons.location_on,
              titulo: 'Município / UF',
              valor: '${vehicle.municipio} / ${vehicle.uf}',
            ),
            _InfoTile(
              icon: Icons.calendar_today,
              titulo: 'Ano (fabricação / modelo)',
              valor: '${vehicle.anoFabricacao} / ${vehicle.anoModelo}',
            ),
            _InfoTile(
              icon: Icons.confirmation_number,
              titulo: 'Chassi',
              valor: vehicle.chassi,
              copiavel: true,
            ),
            _InfoTile(
              icon: Icons.settings,
              titulo: 'Número do motor',
              valor: vehicle.numeroMotor,
            ),

            const Divider(height: 32),

            // Consultas adicionais (sob demanda) — roubo/furto.
            Text(
              'Consultas adicionais',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Cada consulta é feita à parte, apenas se você quiser.',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            _ConsultaOpcional(
              icon: Icons.badge_outlined,
              titulo: 'RENAVAM',
              status: controller.renavamStatus,
              result: controller.renavamResult,
              erro: controller.renavamErro,
              onConsultar: controller.consultarRenavam,
              copiavel: true,
            ),
            _ConsultaOpcional(
              icon: Icons.report_gmailerrorred,
              titulo: 'Roubo / furto',
              status: controller.rouboStatus,
              result: controller.rouboResult,
              erro: controller.rouboErro,
              onConsultar: controller.consultarRoubo,
            ),
          ],
        ),
      ),
    );
  }
}

// Fix #3: chip de situação legal — verde (regular) ou vermelho (restrição).
class _StatusChip extends StatelessWidget {
  final bool isRegular;
  final String situacao;

  const _StatusChip({required this.isRegular, required this.situacao});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cor = isRegular ? _corVerde(scheme) : scheme.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isRegular ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          size: 16,
          color: cor,
        ),
        const SizedBox(width: 4),
        Text(
          situacao,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cor, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Linha de dado cadastral reutilizável (ícone + título + valor).
/// Quando [copiavel] é true, exibe um botão de cópia à direita.
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String valor;
  final bool copiavel;

  const _InfoTile({
    required this.icon,
    required this.titulo,
    required this.valor,
    this.copiavel = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: scheme.primary),
      title: Text(
        titulo,
        style: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      subtitle: Text(
        valor,
        style: textTheme.bodyLarge,
      ),
      trailing: copiavel
          ? IconButton(
              icon: Icon(Icons.copy, size: 20, color: scheme.onSurfaceVariant),
              tooltip: 'Copiar',
              onPressed: () => _copiar(context, valor),
            )
          : null,
    );
  }
}

/// Item de consulta opcional (sob demanda): mostra um botão "Consultar" e, após
/// rodar, exibe o resultado (ou o erro, com opção de tentar de novo).
class _ConsultaOpcional extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final VehicleStatus status;
  final OptionalCheck? result;
  final String? erro;
  final VoidCallback onConsultar;
  final bool copiavel;

  const _ConsultaOpcional({
    required this.icon,
    required this.titulo,
    required this.status,
    required this.result,
    required this.erro,
    required this.onConsultar,
    this.copiavel = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: scheme.primary),
      title: Text(titulo, style: textTheme.bodyLarge),
      subtitle: _subtitle(context),
      trailing: _trailing(context),
    );
  }

  Widget? _subtitle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    switch (status) {
      case VehicleStatus.sucesso:
        final r = result!;
        return Text(
          r.valor,
          style: textTheme.bodyMedium?.copyWith(
            color: r.alerta ? scheme.error : scheme.onSurface,
            fontWeight: r.alerta ? FontWeight.bold : FontWeight.normal,
          ),
        );
      case VehicleStatus.erro:
        return Text(
          erro ?? 'Erro na consulta.',
          style: textTheme.bodySmall?.copyWith(color: scheme.error),
        );
      default:
        return null;
    }
  }

  Widget _trailing(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    switch (status) {
      case VehicleStatus.carregando:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        );
      case VehicleStatus.sucesso:
        final alerta = result!.alerta;
        final statusIcon = Icon(
          alerta ? Icons.warning_amber_rounded : Icons.check_circle,
          color: alerta ? scheme.error : _corVerde(scheme),
        );
        if (copiavel) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.copy, size: 20, color: scheme.onSurfaceVariant),
                tooltip: 'Copiar',
                onPressed: () => _copiar(context, result!.valor),
              ),
              statusIcon,
            ],
          );
        }
        return statusIcon;
      case VehicleStatus.erro:
        return TextButton(
          onPressed: onConsultar,
          child: const Text('Tentar de novo'),
        );
      case VehicleStatus.inicial:
        return FilledButton.tonal(
          onPressed: onConsultar,
          child: const Text('Consultar'),
        );
    }
  }
}

// =============================================================================
// Card de erro customizado
// =============================================================================
class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: scheme.errorContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
