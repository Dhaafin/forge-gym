class ExerciseModel {
  final String id;
  final String name;
  final String targetMuscle;

  ExerciseModel({
    required this.id,
    required this.name,
    required this.targetMuscle,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      id: json['id'] as String,
      name: json['name'] as String,
      targetMuscle: json['target_muscle'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'target_muscle': targetMuscle,
    };
  }
}
