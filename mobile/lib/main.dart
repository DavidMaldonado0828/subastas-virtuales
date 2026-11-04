import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'core/config/api_config.dart';
import 'core/network/api_client.dart';
import 'features/register/bloc/register_bloc.dart';
import 'features/register/pages/register_page.dart';
import 'features/register/repositories/register_repository.dart';
import 'features/register/repositories/register_repository_impl.dart';
import 'features/register/services/register_service.dart';

void main() {
  final storage = const FlutterSecureStorage();
  final client = ApiClient(baseUrl: ApiConfig.baseUrl);
  final service = RegisterService(client: client, storage: storage);
  runApp(
    SubastasApp(
      repository: RegisterRepositoryImpl(service: service),
      storage: storage,
    ),
  );
}

class SubastasApp extends StatelessWidget {
  const SubastasApp({
    required this.repository,
    required this.storage,
    super.key,
  });

  final RegisterRepository repository;
  final FlutterSecureStorage storage;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, state) => RegisterPage(storage: storage),
        ),
        GoRoute(
          path: '/login',
          builder: (_, state) => const Scaffold(
            body: Center(child: Text('Iniciar sesión (pendiente)')),
          ),
        ),
        GoRoute(
          path: '/welcome',
          builder: (_, state) => WelcomePage(alias: state.extra! as String),
        ),
      ],
    );
    return BlocProvider(
      create: (_) => RegisterBloc(repository),
      child: MaterialApp.router(
        title: 'SubastaX',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A73E8),
          ).copyWith(primary: const Color(0xFF1A73E8), surface: Colors.white),
          scaffoldBackgroundColor: Colors.white,
          fontFamily: 'Roboto',
          textTheme: ThemeData.light().textTheme.apply(
            bodyColor: const Color(0xFF1F2937),
            displayColor: const Color(0xFF1F2937),
          ),
          inputDecorationTheme: const InputDecorationTheme(
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD1D5DB)),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF1A73E8), width: 2),
            ),
          ),
        ),
        routerConfig: router,
      ),
    );
  }
}
