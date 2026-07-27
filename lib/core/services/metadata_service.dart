import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:html/parser.dart' as html_parser;
import '../constants/app_constants.dart';

class MetadataResult {
  final String? title;
  final String? thumbnail;
  final String? author;

  MetadataResult({this.title, this.thumbnail, this.author});
}

class MetadataService {
  static const Map<PlatformType, String> _oembedEndpoints = {
    PlatformType.youtube:
        'https://www.youtube.com/oembed?format=json&url=',
    PlatformType.tiktok:
        'https://www.tiktok.com/oembed?format=json&url=',
    PlatformType.instagram:
        'https://api.instagram.com/oembed?format=json&url=',
    PlatformType.facebook:
        'https://graph.facebook.com/v18.0/oembed_?format=json&url=',
  };

  Future<MetadataResult> fetchMetadata(String url, PlatformType platform) async {
    MetadataResult? oembedResult =
        await _tryOEmbed(url, platform);
    if (oembedResult != null && oembedResult.title != null) {
      return oembedResult;
    }

    MetadataResult? ogResult = await _tryOpenGraph(url);
    if (ogResult != null) {
      return ogResult;
    }

    return MetadataResult(
      title: 'Video de ${platform.displayName}',
    );
  }

  Future<MetadataResult?> _tryOEmbed(
      String url, PlatformType platform) async {
    final endpoint = _oembedEndpoints[platform];
    if (endpoint == null) return null;

    try {
      final response = await http
          .get(Uri.parse('$endpoint${Uri.encodeComponent(url)}'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return MetadataResult(
          title: data['title'] as String?,
          thumbnail: data['thumbnail_url'] as String?,
          author: data['author_name'] as String?,
        );
      }
    } catch (_) {}

    return null;
  }

  Future<MetadataResult?> _tryOpenGraph(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);

        String? title;
        String? thumbnail;
        String? author;

        final ogTitle = document.querySelector('meta[property="og:title"]');
        if (ogTitle != null) {
          title = ogTitle.attributes['content'];
        }

        if (title == null) {
          final htmlTitle = document.querySelector('title');
          if (htmlTitle != null) {
            title = htmlTitle.text;
          }
        }

        final ogImage = document.querySelector('meta[property="og:image"]');
        if (ogImage != null) {
          thumbnail = ogImage.attributes['content'];
        }

        final ogSiteName =
            document.querySelector('meta[property="og:site_name"]');
        if (ogSiteName != null) {
          author = ogSiteName.attributes['content'];
        }

        if (title != null || thumbnail != null) {
          return MetadataResult(
            title: title,
            thumbnail: thumbnail,
            author: author,
          );
        }
      }
    } catch (_) {}

    return null;
  }
}
