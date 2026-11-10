import '../../models/my_auctions/my_auction.dart';
import '../../services/my_auctions/my_auctions_service.dart';
import 'my_auctions_repository.dart';

class MyAuctionsRepositoryImpl implements MyAuctionsRepository {
  MyAuctionsRepositoryImpl(this.service);
  final MyAuctionsService service;
  @override
  Future<MyAuctionsPage> fetch({
    required int limit,
    required int offset,
    String? status,
  }) => service.fetch(limit: limit, offset: offset, status: status);
}
