import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/auth_snackbar.dart';
import '../../../core/widgets/auth_link.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../bloc/register_bloc.dart';
import '../../auth/widgets/auth_input.dart';
import '../../auth/bloc/login_bloc.dart';

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
  Widget build(BuildContext context) => BlocListener<LoginBloc, LoginState>(
    listener: (context, loginState) {
      if (loginState is LoginSuccess) context.go('/inicio');
      if (loginState is LoginFailure && loginState.message != null) {
        showAuthSnackbar(context, loginState.message!);
      }
    },
    child: BlocConsumer<RegisterBloc, RegisterState>(
        listener: (context, state) {
          if (state is RegisterFailure && state.message != null) {
            showAuthSnackbar(context, state.message!);
          }
          if (state is RegisterSuccess) {
            context.read<LoginBloc>().add(
              LoginSubmitted(state.user.email, _fields['password']!.text),
            );
          }
        },
        builder: (context, state) {
          if (state is RegisterSuccess) return const SizedBox.shrink();
          if (state is RegisterSubmitting) {
            return _buildForm(context, state, busy: true);
          }
          return _buildForm(context, state, busy: false);
        },
      ),
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
                  PrimaryActionButton(
                    label: 'Registrarme',
                    busy: busy,
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
                  ),
                  const Divider(height: 64),
                  Wrap(
                    alignment: WrapAlignment.start,
                    children: [
                      const Text('¿Ya tienes cuenta? '),
                      AuthLink(
                        label: 'Inicia sesión',
                        onPressed: () {
                          context.go('/login');
                        },
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
  }) => AuthInput(
    key: ValueKey('register-input-$key'),
    controller: _fields[key]!,
    label: label,
    errorText: serverErrors[key]?.isNotEmpty == true ? serverErrors[key] : null,
    keyboardType: keyboard,
    autofillHints: autocomplete,
    obscureText: obscure,
    suffixIcon: suffix,
    onChanged: (_) =>
        context.read<RegisterBloc>().add(RegisterFieldChanged(key)),
  );
}

