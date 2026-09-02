import 'package:delycafe/services/catalog_sync_service.dart';
import 'package:workmanager/workmanager.dart';

const catalogBackgroundTaskName = 'catalogBackgroundRefresh';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == catalogBackgroundTaskName) {
      await CatalogSyncService.backgroundRefresh();
    }

    return true;
  });
}
