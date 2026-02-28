import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

class ApiConfig {
  static String _baseUrl = "";

  static Future<String> loadBaseUrl() async {
    print("the function is called");
    try {
      final uri = Uri.parse(
        'https://gist.githubusercontent.com/EveryTGames/93816d02d5a780bbb48883c1c4dda8d6/raw/neurovive%2520testing%2520gist.txt?timestamp=${DateTime.timestamp().microsecondsSinceEpoch}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        print("requesting the link is success, the url : " + uri.toString());
        // Parse HTML
        final document = html_parser.parse(response.body);
        if(document.body == null)  throw Exception("error happened here in api config");
        _baseUrl = document.body!.innerHtml.trim();


      } else {
        throw Exception('Failed to load API URL');
      }
    } catch (e) {
      // fallback URL or handle error
      print("error happened: $e");
      _baseUrl = "";
    }
    return _baseUrl;
  }

  static String get baseUrl => _baseUrl;
}