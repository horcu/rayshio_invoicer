import 'package:objectbox/objectbox.dart';

@Entity()
class Association {
  Association({required this.clientName, required this.consultantName,
    required this.rate});

  int id = 0;
  String clientName = '';
  String consultantName = '';
  String rate = '';
}