import 'package:delycafe/services/food_phrase_service.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/material.dart';

final foodRouteObserver = RouteObserver<ModalRoute<dynamic>>();

class FoodBrand extends StatefulWidget {
  const FoodBrand({super.key});
  @override
  State<FoodBrand> createState() => _FoodBrandState();
}

class _FoodBrandState extends State<FoodBrand>
    with RouteAware, WidgetsBindingObserver {
  String _phrase = '';
  int _request = 0;
  ModalRoute<dynamic>? _route;
  bool _backgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != _route) {
      foodRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) foodRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() => _refresh();

  Future<void> _refresh() async {
    final request = ++_request;
    final phrase = await FoodPhraseService.instance.next();
    if (mounted && request == _request) setState(() => _phrase = phrase);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgrounded = true;
    } else if (state == AppLifecycleState.resumed && _backgrounded) {
      _backgrounded = false;
      if (_route?.isCurrent ?? false) _refresh();
    }
  }

  @override
  void dispose() {
    foodRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('Деликафе',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.header)),
            ),
          ),
          const SizedBox(width: 50),
          Expanded(
            child: AnimatedSwitcher(
              duration: Duration(
                  milliseconds:
                      MediaQuery.disableAnimationsOf(context) ? 0 : 250),
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.centerRight,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild
                ],
              ),
              child: Text(_phrase,
                  key: ValueKey(_phrase),
                  textAlign: TextAlign.left,
                  softWrap: true,
                  style:
                      const TextStyle(fontSize: 14, color: AppColors.header)),
            ),
          ),
        ],
      );
}
