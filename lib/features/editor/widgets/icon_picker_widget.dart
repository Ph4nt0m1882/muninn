import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:muninn/features/editor/utils/icon_list.dart';
import 'package:muninn/features/editor/utils/emoji_list.dart';
import 'package:muninn/features/editor/utils/symbol_list.dart';
import 'package:unicode_emojis/unicode_emojis.dart';

class IconPickerWidget extends StatefulWidget {
  final Function(String, String) onIconSelected;

  const IconPickerWidget({super.key, required this.onIconSelected});

  static Future<void> show(
    BuildContext context,
    Function(String, String) onIconSelected,
  ) {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 1000,
          height: 700,
          child: IconPickerWidget(onIconSelected: onIconSelected),
        ),
      ),
    );
  }

  @override
  State<IconPickerWidget> createState() => _IconPickerWidgetState();
}

class _IconPickerWidgetState extends State<IconPickerWidget> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Selected state
  String? _selectedIconName; // Used for icons
  IconData? _selectedIconData; // Used for icons
  String? _selectedSymbol; // Used for symbols and emojis
  String? _selectedSymbolName; // Used for bottom panel text
  String _currentLibrary =
      'lucide'; // 'lucide', 'simple', 'material', 'emoji', 'symbol'

  double _iconSize = 32.0;

  late final List<Emoji> _allEmojis;

  @override
  void initState() {
    super.initState();
    _allEmojis = getSafeEmojis();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _changeLibrary(String library) {
    setState(() {
      if (_currentLibrary != library) {
        _currentLibrary = library;
        _selectedIconName = null;
        _selectedIconData = null;
        _selectedSymbol = null;
        _selectedSymbolName = null;
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  List<MapEntry<String, IconData>> _filteredIcons(
    Map<String, IconData> iconsMap,
  ) {
    if (_searchQuery.isEmpty) return iconsMap.entries.toList();
    return iconsMap.entries
        .where((e) => e.key.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<Emoji> get _filteredEmojis {
    if (_searchQuery.isEmpty) return _allEmojis;
    final q = _searchQuery.toLowerCase();
    return _allEmojis.where((e) {
      if (e.name.toLowerCase().contains(q)) return true;
      if (e.shortNames.any((sn) => sn.toLowerCase().contains(q))) return true;
      return false;
    }).toList();
  }

  List<MapEntry<String, String>> get _filteredSymbols {
    if (_searchQuery.isEmpty) return symbolListMap.entries.toList();
    final q = _searchQuery.toLowerCase();
    return symbolListMap.entries
        .where(
          (e) =>
              e.key.toLowerCase().contains(q) ||
              e.value.toLowerCase().contains(q),
        )
        .toList();
  }

  void _onInsert() {
    if ((_currentLibrary == 'symbol' || _currentLibrary == 'emoji') &&
        _selectedSymbol != null) {
      widget.onIconSelected(_selectedSymbol!, _currentLibrary);
      Navigator.pop(context);
    } else if (_selectedIconName != null) {
      widget.onIconSelected(_selectedIconName!, _currentLibrary);
      Navigator.pop(context);
    }
  }

  void _onCopy() {
    if ((_currentLibrary == 'symbol' || _currentLibrary == 'emoji') &&
        _selectedSymbol != null) {
      Clipboard.setData(ClipboardData(text: _selectedSymbol!));
    } else if (_selectedIconName != null) {
      Clipboard.setData(ClipboardData(text: _selectedIconName!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExcludeSemantics(
      child: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: theme.colorScheme.surfaceContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    'Catégories',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildSideMenuItem(
                  'Lucide',
                  'lucide',
                  Icons.interests_outlined,
                ),
                _buildSideMenuItem(
                  'Simple Icons',
                  'simple',
                  Icons.layers_outlined,
                ),
                _buildSideMenuItem(
                  'Material',
                  'material',
                  Icons.category_outlined,
                ),
                _buildSideMenuItem(
                  'Emojis',
                  'emoji',
                  Icons.emoji_emotions_outlined,
                ),
                _buildSideMenuItem('Symboles', 'symbol', Icons.functions),
                const Spacer(),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taille d\'affichage',
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.format_size, size: 16),
                          Expanded(
                            child: Slider(
                              value: _iconSize,
                              min: 24,
                              max: 64,
                              onChanged: (val) {
                                setState(() => _iconSize = val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Area
          Expanded(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: theme.dividerColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                          decoration: InputDecoration(
                            hintText: 'Rechercher une icône ou un symbole...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Fermer',
                      ),
                    ],
                  ),
                ),

                // Grid
                Expanded(child: _buildCurrentGrid()),

                // Bottom Action Panel
                if (_selectedIconName != null || _selectedSymbol != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border(
                        top: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (_selectedIconData != null) ...[
                          Icon(
                            _selectedIconData,
                            size: 32,
                            color: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _selectedIconName!,
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else if (_selectedSymbol != null) ...[
                          Text(
                            _selectedSymbol!,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _selectedSymbolName ?? 'Caractère',
                              style: theme.textTheme.titleMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        ElevatedButton.icon(
                          onPressed: _onCopy,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copier'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _onInsert,
                          icon: const Icon(Icons.check),
                          label: const Text('Insérer'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideMenuItem(String label, String library, IconData icon) {
    final isSelected = _currentLibrary == library;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _changeLibrary(library),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentGrid() {
    switch (_currentLibrary) {
      case 'lucide':
        return _buildIconGrid(_filteredIcons(lucideIconsMap), 'lucide');
      case 'simple':
        return _buildIconGrid(_filteredIcons(simpleIconsMap), 'simple');
      case 'material':
        return _buildIconGrid(_filteredIcons(materialIconsMap), 'material');
      case 'emoji':
        return _buildEmojiGrid(_filteredEmojis);
      case 'symbol':
        return _buildSymbolGrid(_filteredSymbols);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildIconGrid(
    List<MapEntry<String, IconData>> icons,
    String library,
  ) {
    if (icons.isEmpty) {
      return const Center(child: Text('Aucune icône trouvée.'));
    }
    return ExcludeSemantics(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _iconSize + 60,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: icons.length,
        itemBuilder: (context, index) {
          final iconEntry = icons[index];
          final isSelected =
              _selectedIconName == iconEntry.key && _currentLibrary == library;

          return _buildGridItem(
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedIconName = iconEntry.key;
                _selectedIconData = iconEntry.value;
                _selectedSymbol = null;
                _selectedSymbolName = null;
              });
            },
            onDoubleTap: () {
              setState(() {
                _selectedIconName = iconEntry.key;
                _selectedIconData = iconEntry.value;
              });
              _onInsert();
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconEntry.value,
                  size: _iconSize,
                  color: isSelected
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  iconEntry.key.split('-').last,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmojiGrid(List<Emoji> emojis) {
    if (emojis.isEmpty) {
      return const Center(child: Text('Aucun emoji trouvé.'));
    }
    return ExcludeSemantics(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _iconSize + 60,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          final emoji = emojis[index];
          final isSelected =
              _selectedSymbol == emoji.emoji && _currentLibrary == 'emoji';

          return _buildGridItem(
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedSymbol = emoji.emoji;
                _selectedSymbolName = emoji.name;
                _selectedIconName = null;
                _selectedIconData = null;
              });
            },
            onDoubleTap: () {
              setState(() {
                _selectedSymbol = emoji.emoji;
                _selectedSymbolName = emoji.name;
              });
              _onInsert();
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji.emoji, style: TextStyle(fontSize: _iconSize)),
                const SizedBox(height: 8),
                Text(
                  emoji.name,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSymbolGrid(List<MapEntry<String, String>> symbols) {
    if (symbols.isEmpty) {
      return const Center(child: Text('Aucun symbole trouvé.'));
    }
    return ExcludeSemantics(
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _iconSize + 60,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.7,
        ),
        itemCount: symbols.length,
        itemBuilder: (context, index) {
          final entry = symbols[index];
          final symbol = entry.key;
          final name = entry.value;
          final isSelected =
              _selectedSymbol == symbol && _currentLibrary == 'symbol';

          return _buildGridItem(
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedSymbol = symbol;
                _selectedSymbolName = name;
                _selectedIconName = null;
                _selectedIconData = null;
              });
            },
            onDoubleTap: () {
              setState(() {
                _selectedSymbol = symbol;
                _selectedSymbolName = name;
              });
              _onInsert();
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  symbol,
                  style: TextStyle(
                    fontSize: _iconSize,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridItem({
    required bool isSelected,
    required VoidCallback onTap,
    required VoidCallback onDoubleTap,
    required Widget child,
  }) {
    return InkWell(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: child,
      ),
    );
  }
}
