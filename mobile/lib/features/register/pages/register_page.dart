import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../bloc/register_bloc.dart';
import '../widgets/register_input.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({required this.storage, super.key});
  final FlutterSecureStorage storage;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _fields = {
    for (final key in [
      'name',
      'alias',
      'email',
      'phone_number',
      'password',
      'confirmPassword',
      'address',
    ])
      key: TextEditingController(),
  };
  bool _showPassword = false;
  bool _showConfirmation = false;

  void _togglePasswordVisibility(
    TextEditingController controller, {
    required bool confirmation,
  }) {
    final selection = controller.selection;
    setState(() {
      if (confirmation) {
        _showConfirmation = !_showConfirmation;
      } else {
        _showPassword = !_showPassword;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          selection.isValid &&
          selection.start <= controller.text.length &&
          selection.end <= controller.text.length) {
        controller.selection = selection;
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<RegisterBloc, RegisterState>(
        listener: (context, state) {
          if (state is RegisterFailure && state.message != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.message!)));
          }
          if (state is RegisterSuccess) {
            context.go('/welcome', extra: state.user.alias);
          }
        },
        builder: (context, state) {
          if (state is RegisterSuccess) return const SizedBox.shrink();
          if (state is RegisterSubmitting) {
            return _buildForm(context, state, busy: true);
          }
          return _buildForm(context, state, busy: false);
        },
      );

  Widget _buildForm(
    BuildContext context,
    RegisterState state, {
    required bool busy,
  }) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(30, 32, 30, 30),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Image.asset(
                      'assets/branding/subastax_logo.png',
                      width: 320,
                      height: 110,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      semanticLabel: 'SubastaX',
                    ),
                  ),
                  const SizedBox(height: 38),
                  const Text(
                    'Registrarse',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _field(
                    'Nombre completo',
                    'name',
                    state.fieldErrors,
                    maxLength: 100,
                    autocomplete: [AutofillHints.name],
                  ),
                  _field(
                    'Nombre de usuario',
                    'alias',
                    state.fieldErrors,
                    maxLength: 50,
                    autocomplete: [AutofillHints.username],
                  ),
                  _field(
                    'Correo',
                    'email',
                    state.fieldErrors,
                    keyboard: TextInputType.emailAddress,
                    autocomplete: [AutofillHints.email],
                  ),
                  _field(
                    'Teléfono',
                    'phone_number',
                    state.fieldErrors,
                    maxLength: 20,
                    keyboard: TextInputType.phone,
                    autocomplete: [AutofillHints.telephoneNumber],
                  ),
                  _field(
                    'Contraseña',
                    'password',
                    state.fieldErrors,
                    obscure: !_showPassword,
                    suffix: SizedBox(
                      width: 48,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _fields['password']!,
                        builder: (context, value, child) => IconButton(
                              tooltip: _showPassword
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              onPressed: value.text.isEmpty
                                  ? null
                                  : () => _togglePasswordVisibility(
                                      _fields['password']!,
                                      confirmation: false,
                                    ),
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: value.text.isEmpty
                                    ? Colors.transparent
                                    : null,
                              ),
                            ),
                      ),
                    ),
                    hint: 'Mínimo 8 caracteres',
                    autocomplete: [AutofillHints.newPassword],
                  ),
                  _field(
                    'Confirmar contraseña',
                    'confirmPassword',
                    state.fieldErrors,
                    obscure: !_showConfirmation,
                    suffix: SizedBox(
                      width: 48,
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _fields['confirmPassword']!,
                        builder: (context, value, child) => IconButton(
                              tooltip: _showConfirmation
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              onPressed: value.text.isEmpty
                                  ? null
                                  : () => _togglePasswordVisibility(
                                      _fields['confirmPassword']!,
                                      confirmation: true,
                                    ),
                              icon: Icon(
                                _showConfirmation
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: value.text.isEmpty
                                    ? Colors.transparent
                                    : null,
                              ),
                            ),
                      ),
                    ),
                    autocomplete: [AutofillHints.newPassword],
                  ),
                  _field(
                    'Dirección (opcional)',
                    'address',
                    state.fieldErrors,
                    maxLength: 200,
                    autocomplete: [AutofillHints.streetAddressLine1],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Quiero registrarme como:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  RadioGroup<String>(
                    groupValue: state.role,
                    onChanged: (value) {
                      if (!busy && value != null) {
                        context.read<RegisterBloc>().add(
                          RegisterRoleChanged(value),
                        );
                      }
                    },
                    child: Row(
                      children: [
                        const Expanded(
                          child: RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text('Vendedor'),
                            value: 'VENDEDOR',
                          ),
                        ),
                        const Expanded(
                          child: RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text('Participante'),
                            value: 'POSTOR',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.role == 'POSTOR') ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Acepto la política de pujas (las pujas son vinculantes y no pueden retirarse).',
                      ),
                      value: state.acceptedPolicy,
                      onChanged: busy
                          ? null
                          : (value) => context.read<RegisterBloc>().add(
                              RegisterPolicyChanged(value ?? false),
                            ),
                    ),
                    if (state.fieldErrors['accept_bid_policy']
                        case final error?)
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: busy
                          ? null
                          : () {
                              context.read<RegisterBloc>().add(
                                RegisterSubmitted({
                                  for (final entry in _fields.entries)
                                    entry.key: entry.value.text,
                                }),
                              );
                            },
                      child: busy
                          ? const SizedBox(
                              width: 23,
                              height: 23,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Registrarme',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const Divider(height: 64),
                  Wrap(
                    alignment: WrapAlignment.start,
                    children: [
                      const Text('¿Ya tienes cuenta? '),
                    GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text(
                          'Inicia sesión',
                          style: TextStyle(color: Color(0xFF1A73E8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _field(
    String label,
    String key,
    Map<String, String> serverErrors, {
    int? maxLength,
    TextInputType? keyboard,
    Iterable<String>? autocomplete,
    bool obscure = false,
    Widget? suffix,
    String? hint,
  }) => RegisterInput(
    key: ValueKey('register-input-$key'),
    controller: _fields[key]!,
    label: label,
    errorText: serverErrors[key]?.isNotEmpty == true
        ? serverErrors[key]
        : null,
    hasError: serverErrors.containsKey(key),
    maxLength: maxLength,
    keyboardType: keyboard,
    autofillHints: autocomplete,
    obscureText: obscure,
    suffixIcon: suffix,
    hintText: hint,
    onChanged: (_) =>
        context.read<RegisterBloc>().add(RegisterFieldChanged(key)),
  );
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({required this.alias, super.key});
  final String alias;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '¡Bienvenido, $alias!',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                context.read<RegisterBloc>().add(const RegisterLoggedOut());
                context.go('/');
              },
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    ),
  );
}

