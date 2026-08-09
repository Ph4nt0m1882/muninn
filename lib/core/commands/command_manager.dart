import 'package:flutter/material.dart';
import 'package:muninn/core/commands/commands.dart';

class CommandManager extends ChangeNotifier {
  static final CommandManager instance = CommandManager._();
  CommandManager._();

  final Map<String, AppCommand> _commands = {};

  void register(AppCommand command) {
    _commands[command.id] = command;
    notifyListeners();
  }

  void unregister(String id) {
    _commands.remove(id);
    notifyListeners();
  }

  void execute(String id) {
    if (_commands.containsKey(id)) {
      _commands[id]!.execute();
    } else {
      debugPrint('Commande inconnue: $id');
    }
  }

  List<AppCommand> get allCommands => _commands.values.toList();
}
