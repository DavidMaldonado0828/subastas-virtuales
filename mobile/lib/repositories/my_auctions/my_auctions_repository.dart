import '../../models/my_auctions/my_auction.dart';

abstract interface class MyAuctionsRepository {
  Future<MyAuctionsPage> fetch({
    required int limit,
    required int offset,
    String? status,
  });
}
