import 'package:dio/dio.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_client.dart';
import '../models/auction.dart';

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
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final imageUri = Uri.parse(imageUrl);
        final configuredOrigin = Uri.parse(ApiConfig.serverOrigin);
        product['image_url'] = configuredOrigin.replace(
          path: imageUri.path,
          query: imageUri.hasQuery ? imageUri.query : null,
          fragment: imageUri.hasFragment ? imageUri.fragment : null,
        ).toString();
      }
      item['product'] = product;
      return item;
    }).toList(growable: false);
    data['items'] = items;
    return AuctionPage.fromJson(data);
  }
}
