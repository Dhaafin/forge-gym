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

abstract class TargetMuscle {
  static const String chest = 'Chest';
  static const String back = 'Back';
  static const String legs = 'Legs';
  static const String shoulders = 'Shoulders';
  static const String arms = 'Arms';
  static const String core = 'Core';
  static const String cardio = 'Cardio';
  static const String fullBody = 'Full Body';

  static const List<String> values = [
    chest,
    back,
    legs,
    shoulders,
    arms,
    core,
    cardio,
    fullBody,
  ];

  static const List<String> filterValues = [
    'All',
    chest,
    back,
    legs,
    shoulders,
    arms,
    core,
    cardio,
    fullBody,
  ];
}
