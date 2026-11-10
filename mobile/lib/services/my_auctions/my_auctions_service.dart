import '../../../core/network/api_client.dart';
import '../../models/my_auctions/my_auction.dart';

class MyAuctionsService {
  MyAuctionsService({required this.client});
  final ApiClient client;
  Future<MyAuctionsPage> fetch({
    required int limit,
    required int offset,
    String? status,
  }) async {
    final response = await client.dio.get<Map<String, dynamic>>(
      '/me/auctions',
      queryParameters: {'limit': limit, 'offset': offset, 'status': ?status},
    );
    return MyAuctionsPage.fromJson(Map<String, dynamic>.from(response.data!));
  }
}
