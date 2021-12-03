import 'package:objectbox/objectbox.dart';

@Entity()
class PayRate {
  PayRate({required this.rate});

  int id = 0;
  String rate = '';
}