import 'package:http/http.dart' as http;
import 'dart:convert';

class OllamaService {
  // For Android Emulator use 10.0.2.2, for physical device use your machine's IP
  static const String ollamaHost = '10.0.2.2'; 
  static const int ollamaPort = 11434;

  static Future<Map<String, dynamic>> parseReceipt(String receiptText) async {
    final response = await http.post(
      Uri.parse('http://$ollamaHost:$ollamaPort/api/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "model": "gpt-oss:120b-cloud",
        "stream": false,
        "prompt":
            """
        You are a receipt parser. 
        Read the text below and return valid JSON with:
        {
          "date": "",
          "items": [
            {
              "id": "item_01",
              "name": "",
              "category": "",
              "totalPrice": 0
            }
          ]
          "location": "",
          "name": "",
          "totalAmount": 0,
        }

        Rules:
        - Output ONLY JSON, no explanations.
        - If data is missing, use "" or 0.
        - Prices must match the receipt exactly.
        - Items must be in order, with ids like item_001, item_002, etc.
        - Categories: Medical, Entertainment, Essentials, Utilities, Food, Misc, Transportation.

Receipt text:
$receiptText
""",
      }),
    );

    if (response.statusCode != 200) {
      print('Ollama error ${response.statusCode}: ${response.body}');
      throw Exception('Failed to parse receipt: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final responseText = data['response'] as String;

    // Extract JSON from the response text
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(responseText);
    if (jsonMatch == null) {
      throw Exception('No JSON found in response');
    }

    return jsonDecode(jsonMatch.group(0)!);
  }
}
