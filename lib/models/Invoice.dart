import 'package:objectbox/objectbox.dart';

@Entity()
class Invoice {

  Invoice({required this.path, required this.label, required this.dueDate,
    required this.creationDate});

  int id = 0;
  String path = '';
  String label = '';
  String dueDate = '';
  String creationDate = '';
  bool paid = false;

}