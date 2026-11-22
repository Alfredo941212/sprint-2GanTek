import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../../core/network/api_client.dart';
import '../models/ai_chat_response.dart';

class AiChatRepository {
  final ApiClient _apiClient = ApiClient.instance;

  Future<AiChatResponse> sendMessage({
    required String pregunta,
  }) async {
    final response = await _apiClient.post(
      '/ia/chat',
      body: {
        'pregunta': pregunta.trim(),
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'No se pudo obtener respuesta del asistente. '
        'Código: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception(
        'La respuesta del servidor no tiene un formato válido.',
      );
    }

    final success = decoded['success'] == true;

    if (!success) {
      throw Exception(
        decoded['message']?.toString() ??
            'El asistente no devolvió una respuesta.',
      );
    }

    return AiChatResponse.fromJson(decoded);
  }

  Future<String> downloadFile(
    AiChatResponse response,
  ) async {
    if (!response.esArchivo || response.url == null || response.url!.isEmpty) {
      throw Exception(
        'No existe un archivo disponible para descargar.',
      );
    }

    final result = await _apiClient.get(
      response.url!,
    );

    if (result.statusCode < 200 || result.statusCode >= 300) {
      throw Exception(
        'No se pudo descargar el archivo. '
        'Código: ${result.statusCode}',
      );
    }

    final directory = await getApplicationDocumentsDirectory();

    final extension =
        response.formato?.toLowerCase() == 'excel' ? 'xlsx' : 'pdf';

    final fileName = 'reporte_produccion_'
        '${DateTime.now().millisecondsSinceEpoch}'
        '.$extension';

    final file = File(
      '${directory.path}${Platform.pathSeparator}$fileName',
    );

    await file.writeAsBytes(
      result.bodyBytes,
      flush: true,
    );

    return file.path;
  }
}
