class Usuario {
  final int id;
  final String nome;
  final String email;
  final int idPerfil;
  final String perfilNome;
  final String token;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.idPerfil,
    required this.perfilNome,
    required this.token,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      nome: json['nome'],
      email: json['email'],
      idPerfil: json['id_perfil'],
      perfilNome: json['perfil_nome'],
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'id_perfil': idPerfil,
      'perfil_nome': perfilNome,
      'token': token,
    };
  }

  bool isApontador() => idPerfil == 5;
  bool isOperador() => idPerfil == 4;
}