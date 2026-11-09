import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'core/auth/auth_session.dart';
import 'core/config/api_config.dart';
import 'core/network/api_client.dart';
import 'bloc/auth/login_bloc.dart';
import 'bloc/register/register_bloc.dart';
import 'bloc/detail/detail_bloc.dart';
import 'bloc/detail/bid_bloc.dart';
import 'pages/auth/login_page.dart';
import 'pages/home/home_page.dart';
import 'pages/register/register_page.dart';
import 'pages/detail/auction_detail_page.dart';
import 'repositories/auth/auth_repository.dart';
import 'repositories/auth/auth_repository_impl.dart';
import 'repositories/home/auction_repository.dart';
import 'repositories/home/auction_repository_impl.dart';
import 'repositories/register/register_repository.dart';
import 'repositories/register/register_repository_impl.dart';
import 'repositories/detail/detail_repository.dart';
import 'repositories/detail/detail_repository_impl.dart';
import 'services/auth/auth_service.dart';
import 'services/home/auction_service.dart';
import 'services/register/register_service.dart';
import 'services/detail/detail_service.dart';

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
  final detailRepository = DetailRepositoryImpl(DetailService(client: client));
  runApp(
    SubastasApp(
      repository: RegisterRepositoryImpl(service: registerService),
      authRepository: AuthRepositoryImpl(service: authService),
      storage: storage,
      session: session,
      auctionRepository: auctionRepository,
      detailRepository: detailRepository,
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
    required this.detailRepository,
    super.key,
  });

  final RegisterRepository repository;
  final AuthRepository authRepository;
  final FlutterSecureStorage storage;
  final AuthSession session;
  final AuctionRepository auctionRepository;
  final DetailRepository detailRepository;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      refreshListenable: session,
      redirect: (context, state) {
        final path = state.matchedLocation;
        if (path == '/') {
          return session.isAuthenticated ? '/inicio' : '/login';
        }
        if ((path == '/inicio' || path.startsWith('/subasta/')) &&
            !session.isAuthenticated) {
          return '/login';
        }
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
        GoRoute(
          path: '/subasta/:id',
          builder: (context, state) {
            final auctionId =
                int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => DetailBloc(detailRepository)),
                BlocProvider(create: (_) => BidBloc(detailRepository)),
              ],
              child: AuctionDetailPage(
                auctionId: auctionId,
                role: session.user?.role ?? '',
                userAlias: session.user?.alias ?? '',
              ),
            );
          },
        ),
      ],
    );
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<RegisterRepository>.value(value: repository),
        RepositoryProvider<AuthRepository>.value(value: authRepository),
        RepositoryProvider<AuctionRepository>.value(value: auctionRepository),
        RepositoryProvider<DetailRepository>.value(value: detailRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => RegisterBloc(repository)),
          BlocProvider(create: (_) => LoginBloc(authRepository)),
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
