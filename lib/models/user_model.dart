import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class UserModel extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int age;

  @HiveField(2)
  String profession;

  @HiveField(3)
  String gender;

  @HiveField(4)
  String stressLevel; // Additional relevant field for mental health

  UserModel({
    required this.name,
    required this.age,
    required this.profession,
    required this.gender,
    required this.stressLevel,
  });
}
