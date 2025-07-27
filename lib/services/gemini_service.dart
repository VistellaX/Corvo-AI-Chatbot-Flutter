import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  final String? apiKey = dotenv.env['GEMINI_API_KEY'];
  final String? apiUrl = dotenv.env['GEMINI_API_URL'];
  static const String _systemPrompt = ''' Descreva a personalidade e regras. 
''';

  Future<String> callGemini(List<Map<String, dynamic>> msgs, String additionalContext) async {
    print('callGemini: inicio da chamada...');

    List<Map<String, dynamic>> localMsgs = [...msgs];

    // adiciona o contexto na requisição
    if (additionalContext.isNotEmpty) {
      localMsgs.insert(0,{
        'role': 'user',
        'parts': [
          {'text': additionalContext}
        ]
      });
    }
    // insere o system prompt no inicio da conversa
    localMsgs.insert(0, {
      'role': 'user',
      'parts': [
        {'text': _systemPrompt}
      ]
    });

    print('callGemini: mensagem construida.');
    final body = {
      'generationConfig': {
        'temperature': 1.0,
        'maxOutputTokens': 32768,
        'topP': 0.95,
        'topK': 64,
      },
      'contents': localMsgs,
    };
    print('callGemini: Body construido');
    final apiUrl = dotenv.env['GEMINI_API_URL'] ?? '';
    print('callGemini: API URL: $apiUrl');
    print('callGemini: Corpo da requisição: ${json.encode(body)}');
    final resp = await http.post(
      Uri.parse(apiUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (resp.statusCode == 200) {
      final data = json.decode(resp.body);
      print('callGemini: response body: ${resp.body}');
      return data['candidates'][0]['content']['parts'][0]['text'] as String;
    } else {
      final errorData = json.decode(resp.body);
      return 'Erro ${resp.statusCode} ao chamar Gemini: ${errorData['error']['message']}';
    }
  }
}