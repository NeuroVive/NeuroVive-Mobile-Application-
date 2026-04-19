import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/api_response.dart';
import 'api_config.dart';

class Api {

  static Future<Response> sendVoice(String path) async {
    final _baseurl = Uri.parse(await ApiConfig.loadBaseUrl());

    print("the link is $_baseurl");
    final wavFile = File(path);

    final wavBytes = await wavFile.readAsBytes();

    final uri = Uri.parse('$_baseurl/voice');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'voice', // field name expected by the API
        wavBytes,
        filename: path
            .split('/')
            .last, //as example: my_record.wav
        contentType: http.MediaType('audio', 'wav'),
      ),
    );




    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 500) {/// we included the 500 here bc the api will send the error from the ai
      return Response(
        status: JobStatus.error,
      );
    }

    final Map<String, dynamic> json =
    jsonDecode(responseBody) as Map<String, dynamic>;

    return Response.fromJson(json);
  }

  static Future<Response> sendImage(String path) async {
    final _baseurl = Uri.parse(await ApiConfig.loadBaseUrl());
    print("the link is $_baseurl");



    final jpgFile = File(path);

    final jpgBytes = await jpgFile.readAsBytes();

    final uri = Uri.parse('$_baseurl/image');
    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      http.MultipartFile.fromBytes(
        'image', // field name expected by the API
        jpgBytes,
        filename: path
            .split('/')
            .last, //as example: my_image.jpg
        contentType: http.MediaType('image', 'jpeg'),
      ),
    );




    final streamedResponse = await request.send();
    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200 && streamedResponse.statusCode != 500) {
      return Response(
        status: JobStatus.error,
      );
    }

    final Map<String, dynamic> json =
    jsonDecode(responseBody) as Map<String, dynamic>;

    return Response.fromJson(json);
  }
}