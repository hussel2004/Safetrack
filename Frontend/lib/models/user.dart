class User {
  final String id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String role;
  final String status;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.role = 'GESTIONNAIRE',
    this.status = 'ACTIF',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id_utilisateur'].toString(),
      username:
          json['email'] ??
          '', // Using email as username for display if username is missing
      email: json['email'] ?? '',
      firstName: json['prenom'] ?? '',
      lastName: json['nom'] ?? '',
      phoneNumber: json['telephone'],
      role: json['role'] ?? 'GESTIONNAIRE',
      status: json['statut'] ?? 'ACTIF',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_utilisateur': int.tryParse(id),
      'email': email,
      'prenom': firstName,
      'nom': lastName,
      'telephone': phoneNumber,
      'role': role,
      'statut': status,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? role,
    String? status,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      status: status ?? this.status,
    );
  }

  // Factory to create a mock user
  factory User.mock() {
    return User(
      id: 'user_123',
      username: 'johndoe',
      email: 'john@safetrack.com',
      firstName: 'John',
      lastName: 'Doe',
      phoneNumber: '+1234567890',
      role: 'ADMIN',
    );
  }
}
