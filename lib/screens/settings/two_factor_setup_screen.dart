import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/auth_service.dart';

class TwoFactorSetupScreen extends StatefulWidget {
  final bool isEnabled;
  final AuthService authService;

  const TwoFactorSetupScreen({
    super.key,
    required this.isEnabled,
    required this.authService,
  });

  @override
  State<TwoFactorSetupScreen> createState() => _TwoFactorSetupScreenState();
}

class _TwoFactorSetupScreenState extends State<TwoFactorSetupScreen> {
  late AuthService _authService;
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isGenerating = false;
  String? _errorMessage;
  String? _successMessage;
  TwoFactorSetupData? _setupData;
  late bool _is2FAEnabled;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService;
    _is2FAEnabled = widget.isEnabled;
    if (!_is2FAEnabled) {
      _generateSetupData();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();
  bool get _isCodeComplete => _code.length == 6;

  Future<void> _generateSetupData() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final data = await _authService.generate2FA();
      setState(() {
        _setupData = data;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al generar código QR. Intenta de nuevo.';
        _isGenerating = false;
      });
    }
  }

  Future<void> _enable2FA() async {
    if (!_isCodeComplete) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.enable2FA(_code);
      setState(() {
        _is2FAEnabled = true;
        _successMessage = '2FA activado correctamente';
        _isLoading = false;
      });
      _clearCode();
    } catch (e) {
      setState(() {
        _errorMessage = 'Código incorrecto. Verifica e intenta de nuevo.';
        _isLoading = false;
      });
    }
  }

  Future<void> _disable2FA() async {
    if (!_isCodeComplete) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.disable2FA(_code);
      setState(() {
        _is2FAEnabled = false;
        _successMessage = '2FA desactivado correctamente';
        _isLoading = false;
        _setupData = null;
      });
      _clearCode();
    } catch (e) {
      setState(() {
        _errorMessage = 'Código incorrecto. Verifica e intenta de nuevo.';
        _isLoading = false;
      });
    }
  }

  void _clearCode() {
    for (final controller in _controllers) {
      controller.clear();
    }
    if (_focusNodes.isNotEmpty) {
      _focusNodes[0].requestFocus();
    }
  }

  void _onCodeChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _copySecret() {
    if (_setupData?.secret != null) {
      Clipboard.setData(ClipboardData(text: _setupData!.secret));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código secreto copiado'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Autenticación de dos factores'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status indicator
              _buildStatusCard(),
              const SizedBox(height: 24),

              // Success message
              if (_successMessage != null) ...[
                _buildMessageCard(_successMessage!, isError: false),
                const SizedBox(height: 16),
              ],

              // Error message
              if (_errorMessage != null) ...[
                _buildMessageCard(_errorMessage!, isError: true),
                const SizedBox(height: 16),
              ],

              if (_is2FAEnabled)
                _buildDisableSection()
              else
                _buildEnableSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _is2FAEnabled ? Colors.green[50] : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _is2FAEnabled ? Colors.green[200]! : Colors.orange[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _is2FAEnabled ? Colors.green[100] : Colors.orange[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _is2FAEnabled ? Icons.security : Icons.security_outlined,
              color: _is2FAEnabled ? Colors.green[700] : Colors.orange[700],
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _is2FAEnabled ? 'Protección activa' : 'Protección inactiva',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _is2FAEnabled ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _is2FAEnabled
                      ? 'Tu cuenta tiene doble factor de autenticación'
                      : 'Activa 2FA para mayor seguridad',
                  style: TextStyle(
                    fontSize: 13,
                    color: _is2FAEnabled ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(String message, {required bool isError}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? Colors.red[50] : Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isError ? Colors.red[200]! : Colors.green[200]!,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? Colors.red[700] : Colors.green[700],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isError ? Colors.red[700] : Colors.green[700],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () {
              setState(() {
                if (isError) {
                  _errorMessage = null;
                } else {
                  _successMessage = null;
                }
              });
            },
            color: isError ? Colors.red[700] : Colors.green[700],
          ),
        ],
      ),
    );
  }

  Widget _buildEnableSection() {
    if (_isGenerating) {
      return const Center(
        child: Column(
          children: [
            SizedBox(height: 48),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generando código QR...'),
          ],
        ),
      );
    }

    if (_setupData == null) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 48),
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text('No se pudo generar el código QR'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _generateSetupData,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Instructions
        Text(
          'Configurar autenticación',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Escanea el código QR con tu app de autenticación',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),

        // QR Code
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _setupData!.otpauthUrl.isNotEmpty
                ? QrImageView(
                    data: _setupData!.otpauthUrl,
                    version: QrVersions.auto,
                    size: 200,
                    backgroundColor: Colors.white,
                    errorStateBuilder: (context, error) {
                      return Container(
                        width: 200,
                        height: 200,
                        color: Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Usa el código manual',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Container(
                    width: 200,
                    height: 200,
                    color: Colors.grey[200],
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'Usa el código manual',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),

        // Manual code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Código manual',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: _copySecret,
                    tooltip: 'Copiar',
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                _setupData!.secret,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Verification section
        Text(
          'Verificar configuración',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa el código de 6 dígitos de tu app',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        // Code input
        _buildCodeInput(),
        const SizedBox(height: 24),

        // Enable button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading || !_isCodeComplete ? null : _enable2FA,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Activar 2FA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 24),

        // Help info
        _buildHelpInfo(),
      ],
    );
  }

  Widget _buildDisableSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Warning
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[700], size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Desactivar 2FA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Esto reducirá la seguridad de tu cuenta',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Verification section
        Text(
          'Verificar identidad',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ingresa el código de tu app de autenticación para confirmar',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        // Code input
        _buildCodeInput(),
        const SizedBox(height: 24),

        // Disable button
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isLoading || !_isCodeComplete ? null : _disable2FA,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Desactivar 2FA',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCodeInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 48,
          height: 56,
          child: RawKeyboardListener(
            focusNode: FocusNode(),
            onKey: (event) => _onKeyDown(index, event),
            child: TextFormField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).primaryColor,
                    width: 2,
                  ),
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (value) => _onCodeChanged(index, value),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHelpInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Apps recomendadas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAppRow('Google Authenticator'),
          _buildAppRow('Microsoft Authenticator'),
          _buildAppRow('Authy'),
          _buildAppRow('1Password'),
        ],
      ),
    );
  }

  Widget _buildAppRow(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Text(
            name,
            style: TextStyle(color: Colors.blue[800]),
          ),
        ],
      ),
    );
  }
}
