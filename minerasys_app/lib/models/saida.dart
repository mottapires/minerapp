class Saida {
  final int? id;
  final String? tempId;
  final int idUsuario;
  final String placa;
  final double metrosCubicos;
  final double valorRecebido;
  final String? motorista;
  final String dataSaida;
  final String horario;
  final bool sincronizado;

  Saida({
    this.id,
    this.tempId,
    required this.idUsuario,
    required this.placa,
    required this.metrosCubicos,
    required this.valorRecebido,
    this.motorista,
    required this.dataSaida,
    required this.horario,
    this.sincronizado = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'temp_id': tempId,
      'id_usuario': idUsuario,
      'placa': placa,
      'metros_cubicos': metrosCubicos,
      'valor_recebido': valorRecebido,
      'motorista': motorista,
      'data_saida': dataSaida,
      'horario': horario,
      'sincronizado': sincronizado ? 1 : 0,
    };
  }

  factory Saida.fromJson(Map<String, dynamic> json) {
    return Saida(
      id: json['id'],
      tempId: json['temp_id'],
      idUsuario: json['id_usuario'],
      placa: json['placa'],
      metrosCubicos: double.parse(json['metros_cubicos'].toString()),
      valorRecebido: double.parse(json['valor_recebido'].toString()),
      motorista: json['motorista'],
      dataSaida: json['data_saida'],
      horario: json['horario'],
      sincronizado: json['sincronizado'] == 1,
    );
  }
}