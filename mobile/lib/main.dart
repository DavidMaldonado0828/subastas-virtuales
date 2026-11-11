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
import 'pages/my_auctions/my_auctions_page.dart';
import 'pages/seller_products/seller_products_page.dart';
import 'pages/seller_products/seller_product_form_page.dart';
import 'repositories/seller_products/seller_products_repository.dart';
import 'repositories/seller_products/seller_products_repository_impl.dart';
import 'services/seller_products/seller_products_service.dart';
import 'repositories/auth/auth_repository.dart';
import 'repositories/auth/auth_repository_impl.dart';
import 'repositories/home/auction_repository.dart';
import 'repositories/home/auction_repository_impl.dart';
import 'repositories/register/register_repository.dart';
import 'repositories/register/register_repository_impl.dart';
import 'repositories/detail/detail_repository.dart';
import 'repositories/detail/detail_repository_impl.dart';
import 'repositories/my_auctions/my_auctions_repository.dart';
import 'repositories/my_auctions/my_auctions_repository_impl.dart';
import 'services/auth/auth_service.dart';
import 'services/home/auction_service.dart';
import 'services/register/register_service.dart';
import 'services/detail/detail_service.dart';
import 'services/my_auctions/my_auctions_service.dart';

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
  final myAuctionsRepository = MyAuctionsRepositoryImpl(
    MyAuctionsService(client: client),
  );
  final sellerProductsRepository = SellerProductsRepositoryImpl(
    SellerProductsService(client: client),
  );
  runApp(
    SubastasApp(
      repository: RegisterRepositoryImpl(service: registerService),
      authRepository: AuthRepositoryImpl(service: authService),
      storage: storage,
      session: session,
      auctionRepository: auctionRepository,
      detailRepository: detailRepository,
      myAuctionsRepository: myAuctionsRepository,
      sellerProductsRepository: sellerProductsRepository,
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
    required this.myAuctionsRepository,
    required this.sellerProductsRepository,
    super.key,
  });

  final RegisterRepository repository;
  final AuthRepository authRepository;
  final FlutterSecureStorage storage;
  final AuthSession session;
  final AuctionRepository auctionRepository;
  final DetailRepository detailRepository;
  final MyAuctionsRepository myAuctionsRepository;
  final SellerProductsRepository sellerProductsRepository;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      refreshListenable: session,
      redirect: (context, state) {
        final path = state.matchedLocation;
        if (path == '/') {
          return session.isAuthenticated ? '/inicio' : '/login';
        }
        if ((path == '/inicio' ||
                path == '/mis-subastas' ||
                path.startsWith('/vendedor/productos') ||
                path.startsWith('/subasta/')) &&
            !session.isAuthenticated) {
          return '/login';
        }
        if (path == '/mis-subastas' && session.user?.role != 'POSTOR') {
          return '/inicio';
        }
        if (path.startsWith('/vendedor/productos') &&
            session.user?.role != 'VENDEDOR') {
          return '/inicio';
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
          path: '/mis-subastas',
          builder: (context, state) => MyAuctionsPage(session: session),
        ),
        GoRoute(
          path: '/vendedor/productos',
          builder: (context, state) =>
              SellerProductsPage(repository: sellerProductsRepository),
        ),
        GoRoute(
          path: '/vendedor/productos/nuevo',
          builder: (context, state) =>
              SellerProductFormPage(repository: sellerProductsRepository),
        ),
        GoRoute(
          path: '/vendedor/productos/:id/editar',
          builder: (context, state) => SellerProductFormPage(
            repository: sellerProductsRepository,
            productId: int.tryParse(state.pathParameters['id'] ?? ''),
          ),
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
        RepositoryProvider<MyAuctionsRepository>.value(
          value: myAuctionsRepository,
        ),
        RepositoryProvider<SellerProductsRepository>.value(
          value: sellerProductsRepository,
        ),
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
