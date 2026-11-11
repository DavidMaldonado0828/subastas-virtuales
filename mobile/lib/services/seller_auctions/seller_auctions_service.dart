import '../../../core/network/api_client.dart';
import '../../models/seller_auctions/seller_auction.dart';
import '../../models/seller_products/seller_product.dart';

class SellerAuctionsService {
  SellerAuctionsService({required this.client});
  final ApiClient client;
  Future<SellerAuctionPage> fetch({
    required int limit,
    required int offset,
  }) async {
    final response = await client.dio.get<Map<String, dynamic>>(
      '/me/seller/auctions',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return SellerAuctionPage.fromJson(
      Map<String, dynamic>.from(response.data!),
    );
  }

  Future<List<SellerAuction>> fetchAll() async {
    const limit = 100;
    var offset = 0;
    final items = <SellerAuction>[];
    while (true) {
      final page = await fetch(limit: limit, offset: offset);
      items.addAll(page.items);
      offset += page.items.length;
      if (page.items.length < limit) return items;
    }
  }

  Future<List<SellerProduct>> products() async {
    final response = await client.dio.get<List<dynamic>>('/products');
    return (response.data ?? [])
        .map(
          (raw) =>
              SellerProduct.fromJson(Map<String, dynamic>.from(raw as Map)),
        )
        .toList(growable: false);
  }

  Future<void> create(Map<String, dynamic> payload) async {
    await client.dio.post<void>('/auctions', data: payload);
  }

  Future<void> update(int id, Map<String, dynamic> payload) async {
    await client.dio.patch<void>('/auctions/$id', data: payload);
  }

  Future<SellerBidPage> bids({
    required int id,
    required int limit,
    required int offset,
  }) async {
    final response = await client.dio.get<Map<String, dynamic>>(
      '/auctions/$id/bids',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return SellerBidPage.fromJson(Map<String, dynamic>.from(response.data!));
  }
}
