import 'package:objectbox/objectbox.dart';

@Entity()
class Client {

  Client({required this.name, required this.address});

  int id = 0;
  String name = '';
  String address = '';
}