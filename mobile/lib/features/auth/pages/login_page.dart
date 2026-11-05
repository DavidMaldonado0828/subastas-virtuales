import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/auth_snackbar.dart';
import '../../../core/widgets/auth_link.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../bloc/login_bloc.dart';
import '../widgets/auth_input.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<LoginBloc, LoginState>(
    listener: (context, state) {
      if (state is LoginFailure) {
        _password.clear();
        if (state.message case final message?) {
          showAuthSnackbar(context, message);
        }
      }
      if (state is LoginSuccess) context.go('/inicio');
    },
    builder: (context, state) {
      final busy = state is LoginSubmitting;
      return Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                30,
                32,
                30,
                30 + MediaQuery.viewInsetsOf(context).bottom,
              ),
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
                          semanticLabel: 'SubastaX',
                        ),
                      ),
                      const SizedBox(height: 38),
                      const Text(
                        'Iniciar Sesión',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 24),
                      AuthInput(
                        controller: _email,
                        label: 'Correo',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        errorText: state.fieldErrors['email'],
                        onChanged: (_) => context.read<LoginBloc>().add(
                          const LoginFieldChanged('email'),
                        ),
                      ),
                      AuthInput(
                        controller: _password,
                        label: 'Contraseña',
                        autofillHints: const [AutofillHints.password],
                        obscureText: !_showPassword,
                        errorText: state.fieldErrors['password'],
                        suffixIcon: IconButton(
                          tooltip: _showPassword
                              ? 'Ocultar contraseña'
                              : 'Mostrar contraseña',
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                        onChanged: (_) => context.read<LoginBloc>().add(
                          const LoginFieldChanged('password'),
                        ),
                      ),
                      PrimaryActionButton(
                        label: busy ? 'Ingresando…' : 'Ingresar',
                        busy: busy,
                        onPressed: busy
                            ? null
                            : () => context.read<LoginBloc>().add(
                                LoginSubmitted(_email.text, _password.text),
                              ),
                      ),
                      const Divider(height: 64),
                      Wrap(
                        children: [
                          const Text('¿No tienes cuenta? '),
                          AuthLink(
                            label: 'Regístrate',
                            onPressed: () => context.go('/registro'),
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
    },
  );
}
