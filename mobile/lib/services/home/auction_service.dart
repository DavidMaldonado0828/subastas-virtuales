import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/public_image_url.dart';
import '../../models/home/auction.dart';

class AuctionService {
  AuctionService({required this.client});
  final ApiClient client;

  Future<AuctionPage> fetch({required int limit, required int offset, bool closed = false}) async {
    final response = await client.dio.get<Map<String, dynamic>>(
      '/auctions',
      queryParameters: {
        'limit': limit,
        'offset': offset,
        if (closed) 'status': 'CERRADA',
      },
      options: Options(extra: const {'publicRequest': true}),
    );
    final data = Map<String, dynamic>.from(response.data!);
    final items = (data['items'] as List<dynamic>).map((raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      final product = Map<String, dynamic>.from(item['product'] as Map);
      final imageUrl = product['image_url'] as String?;
      product['image_url'] = publicImageUrl(imageUrl);
      item['product'] = product;
      return item;
    }).toList(growable: false);
    data['items'] = items;
    return AuctionPage.fromJson(data);
  }

  Future<MyAuctionPage> fetchMyAuctions({required int limit, required int offset}) async {
    final response = await client.dio.get<Map<String, dynamic>>(
      '/me/auctions',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return MyAuctionPage.fromJson(Map<String, dynamic>.from(response.data!));
  }
}
