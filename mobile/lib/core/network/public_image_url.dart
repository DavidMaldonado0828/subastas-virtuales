import '../config/api_config.dart';

String? publicImageUrl(String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) return imageUrl;
  final imageUri = Uri.parse(imageUrl);
  final configuredOrigin = Uri.parse(ApiConfig.serverOrigin);
  return configuredOrigin
      .replace(
        path: imageUri.path,
        query: imageUri.hasQuery ? imageUri.query : null,
        fragment: imageUri.hasFragment ? imageUri.fragment : null,
      )
      .toString();
}
