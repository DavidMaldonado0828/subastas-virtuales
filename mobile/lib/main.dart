import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_session.dart';
import 'core/config/api_config.dart';
import 'core/network/api_client.dart';
import 'features/auth/bloc/login_bloc.dart';
import 'features/auth/pages/login_page.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/repositories/auth_repository_impl.dart';
import 'features/auth/services/auth_service.dart';
import 'features/register/bloc/register_bloc.dart';
import 'features/register/pages/register_page.dart';
import 'features/register/repositories/register_repository.dart';
import 'features/register/repositories/register_repository_impl.dart';
import 'features/register/services/register_service.dart';
import 'features/home/bloc/home_bloc.dart';
import 'features/home/pages/home_page.dart';
import 'features/home/repositories/auction_repository.dart';
import 'features/home/repositories/auction_repository_impl.dart';
import 'features/home/services/auction_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();
  final session = AuthSession(storage);
  await session.restore();
  final client = ApiClient(
    baseUrl: ApiConfig.baseUrl,
    storage: storage,
    session: session,
  );
  final registerService = RegisterService(client: client, storage: storage);
  final authService = AuthService(client: client, session: session);
  final auctionRepository = AuctionRepositoryImpl(
    AuctionService(client: client),
  );
  runApp(
    SubastasApp(
      repository: RegisterRepositoryImpl(service: registerService),
      authRepository: AuthRepositoryImpl(service: authService),
      storage: storage,
      session: session,
      auctionRepository: auctionRepository,
    ),
  );
}

class SubastasApp extends StatelessWidget {
  const SubastasApp({
    required this.repository,
    required this.authRepository,
    required this.storage,
    required this.session,
    required this.auctionRepository,
    super.key,
  });

  final RegisterRepository repository;
  final AuthRepository authRepository;
  final FlutterSecureStorage storage;
  final AuthSession session;
  final AuctionRepository auctionRepository;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      refreshListenable: session,
      redirect: (context, state) {
        final path = state.matchedLocation;
        if (path == '/') {
          return session.isAuthenticated ? '/inicio' : '/login';
        }
        if (path == '/inicio' && !session.isAuthenticated) return '/login';
        if (path == '/login' && session.isAuthenticated) return '/inicio';
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SizedBox.shrink(),
        ),
        GoRoute(
          path: '/registro',
          builder: (context, state) => RegisterPage(storage: storage),
        ),
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/inicio',
          builder: (context, state) => HomePage(session: session),
        ),
      ],
    );
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<RegisterRepository>.value(value: repository),
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<AuctionRepository>.value(value: auctionRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => RegisterBloc(repository)),
          BlocProvider(create: (_) => LoginBloc(authRepository)),
          BlocProvider(
            create: (_) => HomeBloc(auctionRepository)
              ..add(const HomeLoadRequested()),
          ),
        ],
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
      ),
    );
  }
}
