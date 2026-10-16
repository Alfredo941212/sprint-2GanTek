import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../models/task_model.dart';

class TaskRepository {
  TaskRepository({
    ApiClient? apiClient,
  }) : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<TaskModel>> getTasks() async {
    final response = await _apiClient.get(
      '/tareas',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'La respuesta de la agenda no tiene el formato esperado.',
        );
      }

      final dynamic data = decoded['data'];

      if (data is! List) {
        return [];
      }

      return data
          .whereType<Map<String, dynamic>>()
          .map(TaskModel.fromJson)
          .toList();
    }

    throw Exception(
      'Error al consultar la agenda. '
      'Código: ${response.statusCode}',
    );
  }

  Future<void> completeTask(
    int taskId,
  ) async {
    final response = await _apiClient.patch(
      '/tareas/$taskId/completar',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(
      'No se pudo completar la tarea. '
      'Código: ${response.statusCode}',
    );
  }

  Future<void> cancelTask(
    int taskId,
  ) async {
    final response = await _apiClient.patch(
      '/tareas/$taskId/cancelar',
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    throw Exception(
      'No se pudo cancelar la tarea. '
      'Código: ${response.statusCode}',
    );
  }

  Future<TaskModel> createTask({
    int? ganadoId,
    int? loteId,
    required String titulo,
    String? descripcion,
    required String tipo,
    required String fecha,
    String? hora,
    required String prioridad,
    required bool recordatorio,
  }) async {
    final response = await _apiClient.post(
      '/tareas',
      body: {
        'ganado_id': ganadoId,
        'lote_id': loteId,
        'titulo': titulo,
        'descripcion': descripcion,
        'tipo': tipo,
        'fecha': fecha,
        'hora': hora,
        'prioridad': prioridad,
        'recordatorio': recordatorio,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'La respuesta no tiene el formato esperado.',
        );
      }

      final dynamic data = decoded['data'];

      if (data is! Map<String, dynamic>) {
        throw Exception(
          'No se recibió la tarea creada.',
        );
      }

      return TaskModel.fromJson(data);
    }

    throw Exception(
      'No se pudo crear la tarea. '
      'Código: ${response.statusCode}',
    );
  }

  Future<TaskModel> updateTask({
    required int taskId,
    int? ganadoId,
    int? loteId,
    required String titulo,
    String? descripcion,
    required String tipo,
    required String fecha,
    String? hora,
    required String prioridad,
    required bool recordatorio,
  }) async {
    final response = await _apiClient.patch(
      '/tareas/$taskId',
      body: {
        'ganado_id': ganadoId,
        'lote_id': loteId,
        'titulo': titulo,
        'descripcion': descripcion,
        'tipo': tipo,
        'fecha': fecha,
        'hora': hora,
        'prioridad': prioridad,
        'recordatorio': recordatorio,
      },
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'La respuesta no tiene el formato esperado.',
        );
      }

      final data = decoded['data'];

      if (data is! Map<String, dynamic>) {
        throw Exception(
          'No se recibió la tarea actualizada.',
        );
      }

      return TaskModel.fromJson(data);
    }

    throw Exception(
      'No se pudo actualizar la tarea. '
      'Código: ${response.statusCode}',
    );
  }
}
