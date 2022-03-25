import 'package:objectbox/objectbox.dart';

@Entity()
class Association {
  Association({required this.clientId, required this.consultantId,
    required this.rateId});

  int id = 0;
  int clientId = 0;
  int consultantId = 0;
  int rateId = 0;
}