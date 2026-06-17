import 'package:delycafe/data/hive/hive_boxes.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> initHive() async {
  await Hive.initFlutter();

  await Hive.openBox<Map>(HiveBoxes.catalog);
  await Hive.openBox(HiveBoxes.user);
  await Hive.openBox(HiveBoxes.orders);
  await Hive.openBox(HiveBoxes.local);
}
