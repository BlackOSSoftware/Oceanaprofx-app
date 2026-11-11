import 'package:flutter/widgets.dart';

class ShellController extends ChangeNotifier {
  int tab = 0;
  String chartSymbol = 'EURUSD';
  bool chartFullscreen = false;

  void openTab(int index) {
    var changed = false;
    if (chartFullscreen) {
      chartFullscreen = false;
      changed = true;
    }
    if (tab != index) {
      tab = index;
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void openChart(String symbol) {
    chartSymbol = symbol;
    tab = 1;
    chartFullscreen = false;
    notifyListeners();
  }

  void setChartFullscreen(bool value) {
    if (chartFullscreen == value) return;
    chartFullscreen = value;
    notifyListeners();
  }
}

class ShellScope extends InheritedWidget {
  const ShellScope({super.key, required this.controller, required super.child});

  final ShellController controller;

  static ShellController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ShellScope>();
    assert(scope != null, 'ShellScope not found');
    return scope!.controller;
  }

  static ShellController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ShellScope>()?.controller;
  }

  @override
  bool updateShouldNotify(ShellScope oldWidget) {
    return controller != oldWidget.controller;
  }
}
