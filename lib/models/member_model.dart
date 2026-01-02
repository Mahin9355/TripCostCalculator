class TourMember {
  final String id;
  final String name;
  final String role; // 'manager' or 'member'

  TourMember({required this.id, required this.name, required this.role});

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'role': role};
  }

  factory TourMember.fromMap(Map<String, dynamic> map) {
    return TourMember(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown',
      role: map['role'] ?? 'member',
    );
  }
}