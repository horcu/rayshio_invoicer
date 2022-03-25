import 'package:objectbox/objectbox.dart';

@Entity()
class Client {

  Client();

  int id = 0;
  String name = '';
  String address1 = '';
  String address2 = '';
  String address3 = '';
  String address4 = '';
}