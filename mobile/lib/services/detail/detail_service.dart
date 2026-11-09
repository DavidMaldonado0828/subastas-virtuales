import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/public_image_url.dart';
import '../../models/detail/auction_detail.dart';
import '../../models/detail/bid_history_item.dart';

class DetailService {
  DetailService({required this.client});

  final ApiClient client;

  Future<AuctionDetail> fetchDetail(int auctionId) async {
    final response = await client.dio.get<Map<String, dynamic>>(
      '/auctions/$auctionId',
      options: Options(extra: const {'publicRequest': true}),
    );
    final data = Map<String, dynamic>.from(response.data!);
    final product = Map<String, dynamic>.from(data['product'] as Map);
    product['image_url'] = publicImageUrl(product['image_url'] as String?);
    data['product'] = product;
    return AuctionDetail.fromJson(data);
  }

  Future<List<BidHistoryItem>> fetchBids(int auctionId) async {
    final response = await client.dio.get<Map<String, dynamic>>(
      '/auctions/$auctionId/bids',
      queryParameters: const {'limit': 5, 'offset': 0},
      options: Options(extra: const {'publicRequest': true}),
    );
    final items = response.data!['items'] as List<dynamic>;
    return List.unmodifiable(
      items.map(
        (item) => BidHistoryItem.fromJson(Map<String, dynamic>.from(item as Map)),
      ),
    );
  }
}
