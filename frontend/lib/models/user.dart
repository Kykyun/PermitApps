class User {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? department;
  final String? phone;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.department,
    this.phone,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      department: json['department'],
      phone: json['phone'],
    );
  }

  String get roleLabel {
    switch (role) {
      case 'worker':
        return 'Pekerja';
      case 'supervisor':
        return 'Supervisor';
      case 'k3_officer':
        return 'Ahli K3';
      case 'admin':
        return 'Admin';
      default:
        return role;
    }
  }
}
