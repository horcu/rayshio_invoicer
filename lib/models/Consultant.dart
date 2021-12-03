import 'package:objectbox/objectbox.dart';

@Entity()
class Consultant {
  Consultant({required this.name, required this.title});

  int id = 0;
  String name = '';
  String title = '';
}