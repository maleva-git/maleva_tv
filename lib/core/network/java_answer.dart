import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

/// Reads the common Java answer `{IsSuccess, StatusCode, Message, Data1}`.
class JavaAnswer {
  JavaAnswer._();

  /// `Data1` of a 2xx answer; otherwise an [ApiException] with the answer's `Message`.
  static dynamic data(http.Response response) {
    final body = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return body['Data1'] ?? body['Data'];
      }
      return body;
    }
    throw ApiException(_message(body) ?? _defaultMessage(response.statusCode), statusCode: response.statusCode);
  }

  static dynamic _decode(String text) {
    if (text.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }

  static String? _message(dynamic body) {
    if (body is Map<String, dynamic>) {
      final message = body['Message'] ?? body['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return null;
  }

  static String _defaultMessage(int status) => switch (status) {
        401 => 'Please sign in again.',
        403 => 'This account cannot open the board.',
        _ => 'Server error ($status).',
      };
}
