import 'package:open_filex/open_filex.dart';
import 'package:flutter/material.dart';
import '../../data/repositories/ai_chat_repository.dart';
import '../../data/models/ai_chat_response.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final AiChatRepository _repository = AiChatRepository();
  final TextEditingController _questionController = TextEditingController();

  AiChatResponse? _response;
  bool _isLoading = false;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _downloadFile() async {
    final response = _response;

    if (response == null || !response.esArchivo) {
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final path = await _repository.downloadFile(
        response,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      final result = await OpenFilex.open(path);

      if (!mounted) {
        return;
      }

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El archivo se descargó, pero no se pudo abrir.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo descargar el archivo.',
          ),
        ),
      );
    }
  }

  Future<void> _sendQuestion() async {
    final question = _questionController.text.trim();

    if (question.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Escribe una pregunta para el asistente.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
      _response = null;
    });

    try {
      final response = await _repository.sendMessage(
        pregunta: question,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _response = response;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo obtener una respuesta del asistente.',
          ),
        ),
      );
    }
  }

  void _useQuickQuestion(String question) {
    _questionController.text = question;
    _sendQuestion();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Asistente GanTek',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Consulta información de tu ganado',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Puedes preguntar sobre producción, ganado, vacunas '
                'y actividades registradas en GanTek.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _questionController,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: '¿Qué deseas consultar?',
                  hintText: 'Ejemplo: ¿Cómo estuvo mi producción esta semana?',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendQuestion,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.send_outlined,
                      ),
                label: Text(
                  _isLoading ? 'Consultando...' : 'Preguntar',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Preguntas rápidas',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text(
                      'Producción semanal',
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            _useQuickQuestion(
                              '¿Cómo estuvo mi producción esta semana?',
                            );
                          },
                  ),
                  ActionChip(
                    label: const Text(
                      'Vacunas próximas',
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            _useQuickQuestion(
                              '¿Qué vacunas tengo próximas?',
                            );
                          },
                  ),
                  ActionChip(
                    label: const Text(
                      'Tareas pendientes',
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            _useQuickQuestion(
                              '¿Qué tareas tengo pendientes?',
                            );
                          },
                  ),
                  ActionChip(
                    label: const Text(
                      'Resumen general',
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            _useQuickQuestion(
                              'Dame un resumen general de mi ganado.',
                            );
                          },
                  ),
                ],
              ),
              if (_response != null) ...[
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.smart_toy_outlined,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'GanTek IA',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SelectableText(
                          _response!.respuesta,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (_response!.esArchivo) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _downloadFile,
                              icon: Icon(
                                _response!.formato == 'excel'
                                    ? Icons.table_chart_outlined
                                    : Icons.picture_as_pdf_outlined,
                              ),
                              label: Text(
                                _response!.formato == 'excel'
                                    ? 'Descargar Excel'
                                    : 'Descargar PDF',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
