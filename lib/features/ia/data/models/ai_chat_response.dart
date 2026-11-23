class AiChatResponse {
  final String tipo;
  final String respuesta;
  final String? formato;
  final String? url;
  final String? periodo;

  const AiChatResponse({
    required this.tipo,
    required this.respuesta,
    this.formato,
    this.url,
    this.periodo,
  });

  bool get esArchivo => tipo == 'archivo';

  factory AiChatResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return AiChatResponse(
      tipo: json['tipo']?.toString() ?? 'texto',
      respuesta: json['respuesta']?.toString() ?? '',
      formato: json['formato']?.toString(),
      url: json['url']?.toString(),
      periodo: json['periodo']?.toString(),
    );
  }
}
