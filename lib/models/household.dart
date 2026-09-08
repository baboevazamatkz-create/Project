class Household {
  final String code;
  final String label;

  const Household({required this.code, required this.label});

  Map<String, dynamic> toJson() => {'code': code, 'label': label};

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        code: json['code'] as String,
        label: json['label'] as String,
      );
}
