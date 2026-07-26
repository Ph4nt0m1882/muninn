import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:munnin/features/editor/widgets/interactive_code_block.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:munnin/features/editor/editor.dart';
import 'package:munnin/features/editor/utils/custom_markdown_syntax.dart';
import 'package:munnin/features/editor/utils/color_parser.dart';
import 'package:munnin/features/editor/widgets/flying_crow_animation.dart';
import 'package:munnin/features/editor/utils/icon_parser.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:munnin/features/editor/services/link_preview_manager.dart';

/// Widget responsable du rendu HTML à partir du Markdown brut.
class MarkdownRenderer extends StatelessWidget {
  /// Le texte brut en Markdown.
  final String content;

  final String? filePath;

  /// Callback déclenché lorsqu'une case à cocher est cliquée.
  final void Function(int id, String newState)? onCheckboxToggled;

  const MarkdownRenderer({
    super.key,
    required this.content,
    this.filePath,
    this.onCheckboxToggled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 0. Pré-traitement pour intercepter les cases à cocher personnalisées
    int checkboxId = 0;
    final String preprocessedContent = content.trim().replaceAllMapped(
      RegExp(r'^(\s*-\s+)\[([ xXvV\*])\]', multiLine: true),
      (match) {
        final prefix = match.group(1)!;
        final state = match.group(2)!.toLowerCase();
        return '$prefix<munnin-checkbox id="${checkboxId++}" state="$state"></munnin-checkbox>';
      },
    );

    // 0.5 Pré-traitement pour préserver l'attribut {edit} des blocs de code
    final String preprocessedContent2 = preprocessedContent.replaceAllMapped(
      RegExp(r'^```([a-zA-Z0-9_\-]+)[ \t]+\{edit\}\s*$', multiLine: true),
      (match) => '```${match.group(1)}-edit',
    );

    // 0.6 Pré-traitement pour les définitions de notes de bas de page [^1]: def
    final String preprocessedContent3 = preprocessedContent2.replaceAllMapped(
      RegExp(r'^\[\^([^\]]+)\]:\s*(.+)$', multiLine: true),
      (match) =>
          '<footnote-def id="${match.group(1)}">${match.group(2)}</footnote-def>',
    );

    // 1. Conversion Markdown -> HTML
    final String htmlContent = md.markdownToHtml(
      preprocessedContent3,
      extensionSet: md
          .ExtensionSet
          .gitHubFlavored, // Support des tables, sans les alertes web pour utiliser notre TagExtension
      inlineSyntaxes: [
        DoubleBangImageSyntax(), // Notre syntaxe custom !![]()
        WikiLinkSyntax(),
        FootnoteRefSyntax(),
      ],
    );

    // 2. Rendu Flutter
    return SingleChildScrollView(
      child: Html(
        data: htmlContent,
        style: _buildHtmlStyles(theme),
        extensions: _buildHtmlExtensions(
          context,
          theme,
          filePath ?? '',
          onCheckboxToggled,
        ),
        onLinkTap: (url, attributes, element) async {
          if (url == null) return;

          // Vérifie si c'est un lien web classique ou un lien de fichier explicite
          if (url.startsWith('http://') ||
              url.startsWith('https://') ||
              url.startsWith('file://')) {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          }
          // Vérifie si c'est un chemin absolu Windows (ex: C:\Dossier ou \\Serveur\Dossier)
          else if (url.contains(RegExp(r'^[a-zA-Z]:\\')) ||
              url.startsWith(r'\\')) {
            final uri = Uri.file(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri);
            }
          }
          // Sinon c'est probablement un lien wiki interne (relatif)
          else {
            debugPrint("Lien wiki interne (à gérer plus tard) : $url");
          }
        },
      ),
    );
  }

  Map<String, Style> _buildHtmlStyles(ThemeData theme) {
    return {
      "body": Style(
        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
        fontSize: FontSize(14.0),
        color: theme.textTheme.bodyMedium?.color,
        margin: Margins.zero,
        padding: HtmlPaddings.zero,
      ),
      "h1": Style(color: theme.colorScheme.primary),
      "h2": Style(color: theme.colorScheme.primary),
      "a": Style(
        color: theme.colorScheme.secondary,
        textDecoration: TextDecoration.none,
      ),
      "code": Style(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        padding: HtmlPaddings.symmetric(horizontal: 4, vertical: 2),
        fontFamily: 'Consolas',
      ),
      "mark": Style(
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.4),
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.bold,
      ),
      "pre": Style(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        padding: HtmlPaddings.all(8),
        fontFamily: 'Consolas',
      ),
      "hr": Style(
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 2)),
        margin: Margins.symmetric(vertical: 16),
      ),
      "blockquote": Style(
        margin: Margins.symmetric(vertical: 8),
        padding: HtmlPaddings.symmetric(horizontal: 16, vertical: 8),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 4),
        ),
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        fontStyle: FontStyle.italic,
      ),
      ".task-list-item": Style(listStyleType: ListStyleType.none),
      "table": Style(
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.5),
          width: 1,
        ),
        margin: Margins.only(bottom: 16.0),
        backgroundColor: theme.colorScheme.surface,
      ),
      "th": Style(
        padding: HtmlPaddings.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 2)),
        fontWeight: FontWeight.bold,
      ),
      "td": Style(
        padding: HtmlPaddings.symmetric(horizontal: 16, vertical: 12),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
    };
  }

  List<HtmlExtension> _buildHtmlExtensions(
    BuildContext context,
    ThemeData theme,
    String filePath,
    void Function(int, String)? onCheckboxToggled,
  ) {
    return [
      TagExtension(
        tagsToExtend: {"wiki-link"},
        builder: (extensionContext) {
          final target = extensionContext.element?.attributes['target'] ?? '';
          final header = extensionContext.element?.attributes['header'] ?? '';
          final alias = extensionContext.element?.innerHtml ?? target;
          return GestureDetector(
            onTapDown: (details) {
              final startPos = details.globalPosition;
              final size = MediaQuery.of(context).size;
              final RenderBox? renderBox =
                  context.findRenderObject() as RenderBox?;
              Offset endPos = Offset(size.width * 0.5, 76); // Fallback

              if (renderBox != null) {
                final Offset rendererGlobalPos = renderBox.localToGlobal(
                  Offset.zero,
                );
                // MarkdownRenderer is right below the 40px tab bar.
                // The center of the tab bar vertically is rendererGlobalPos.dy - 20.
                final double tabCenterY = rendererGlobalPos.dy - 20;

                // Calculate approximate X offset for the new tab
                double totalWidth = 0;
                for (final file in EditorManager.instance.openedFiles) {
                  // Approximate width of an existing tab (padding + icons + text)
                  totalWidth += 80 + (file.name.length * 8);
                }

                // Add half the width of the new tab
                final newTabWidth = 80 + (target.split('/').last.length * 8);
                totalWidth += newTabWidth / 2;

                // The tabs start at the left edge of the MarkdownRenderer area
                // (Assuming padding is minimal, rendererGlobalPos.dx is roughly the left edge)
                endPos = Offset(rendererGlobalPos.dx + totalWidth, tabCenterY);
              }

              bool animationFinished = false;
              FlyingCrowAnimation.show(context, startPos, endPos, () {
                animationFinished = true;
              });

              // Wait for animation to finish, THEN open the file
              () async {
                while (!animationFinished) {
                  await Future.delayed(const Duration(milliseconds: 50));
                }
                EditorManager.instance.resolveWikiLink(
                  target,
                  header,
                  animation: TabOpenAnimation.raven,
                );
              }();
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                alias,
                style: TextStyle(
                  color: theme.colorScheme.tertiary,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
      TagExtension(
        tagsToExtend: {"footnote-ref"},
        builder: (extensionContext) {
          final id = extensionContext.element?.attributes['id'] ?? '';
          return GestureDetector(
            onTap: () {
              debugPrint("Clic sur Footnote Ref : $id");
            },
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Transform.translate(
                offset: const Offset(0, -4),
                child: Text(
                  id,
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      TagExtension(
        tagsToExtend: {"footnote-def"},
        builder: (extensionContext) {
          final id = extensionContext.element?.attributes['id'] ?? '';
          final htmlDefContent = extensionContext.element?.innerHtml ?? '';
          return Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "[$id]: ",
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Html(
                    data: htmlDefContent,
                    style: _buildHtmlStyles(theme),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      TagExtension(
        tagsToExtend: {"a"},
        builder: (extensionContext) {
          final element = extensionContext.element;
          final href = element!.attributes['href'] ?? '';
          final text = element.innerHtml;

          bool isHovered = false;
          return StatefulBuilder(
            builder: (context, setState) {
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (e) {
                  setState(() => isHovered = true);
                  LinkPreviewManager().show(
                    context,
                    href,
                    e.position,
                    filePath,
                  );
                },
                onExit: (e) {
                  setState(() => isHovered = false);
                  LinkPreviewManager().hide();
                },
                child: GestureDetector(
                  onTap: () async {
                    final url = href;
                    if (url.startsWith('http://') ||
                        url.startsWith('https://') ||
                        url.startsWith('file://')) {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    } else if (url.contains(RegExp(r'^[a-zA-Z]:\\')) ||
                        url.startsWith(r'\\')) {
                      final uri = Uri.file(url);
                      if (await canLaunchUrl(uri)) await launchUrl(uri);
                    } else {
                      debugPrint(
                        "Lien wiki interne (à gérer plus tard) : $url",
                      );
                    }
                  },
                  child: Text(
                    text,
                    style: TextStyle(
                      color: theme.colorScheme.secondary,
                      decoration: isHovered
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                      fontSize: 14.0,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      TagExtension(
        tagsToExtend: {"pre"},
        builder: (extensionContext) {
          final element = extensionContext.element;
          if (element == null) return const SizedBox.shrink();

          final codeElement = element.children
              .where((e) => e.localName == 'code')
              .firstOrNull;
          if (codeElement == null) return const SizedBox.shrink();

          String className = codeElement.className;
          String language = '';
          bool isEditable = false;

          if (className.contains('language-')) {
            final match = RegExp(
              r'language-([a-zA-Z0-9_\-]+)',
            ).firstMatch(className);
            if (match != null) {
              language = match.group(1) ?? '';
              if (language.endsWith('-edit')) {
                isEditable = true;
                language = language.substring(0, language.length - 5);
              }
            }
          }

          if (className.contains('{edit}')) {
            isEditable = true;
          }

          String code = codeElement.text;
          if (code.endsWith('\n')) {
            code = code.substring(0, code.length - 1);
          }

          return InteractiveCodeBlock(
            code: code,
            language: language,
            isEditable: isEditable,
            filePath: filePath,
          );
        },
      ),
      TagExtension(
        tagsToExtend: {"table"},
        builder: (extensionContext) {
          final element = extensionContext.element;
          if (element == null) return const SizedBox.shrink();

          final rows = element.getElementsByTagName("tr");
          if (rows.isEmpty) return const SizedBox.shrink();

          final tableRows = <TableRow>[];
          bool isEven = false;

          for (var row in rows) {
            final cells = row.children
                .where((e) => e.localName == 'td' || e.localName == 'th')
                .toList();
            if (cells.isEmpty) continue;

            final tableCells = <Widget>[];
            for (var cell in cells) {
              final isHeader = cell.localName == 'th';
              final alignAttr = cell.attributes['align'] ?? '';
              final styleAttr = cell.attributes['style'] ?? '';
              TextAlign textAlign = TextAlign.left;
              if (alignAttr == 'right' || styleAttr.contains('right')) {
                textAlign = TextAlign.right;
              } else if (alignAttr == 'center' ||
                  styleAttr.contains('center')) {
                textAlign = TextAlign.center;
              }

              tableCells.add(
                Container(
                  color: isHeader
                      ? theme.colorScheme.surfaceContainerHighest
                      : (isEven
                            ? theme.colorScheme.surfaceContainerLow
                            : theme.colorScheme.surface),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  alignment: textAlign == TextAlign.center
                      ? Alignment.center
                      : (textAlign == TextAlign.right
                            ? Alignment.centerRight
                            : Alignment.centerLeft),
                  child: DefaultTextStyle.merge(
                    textAlign: textAlign,
                    style: TextStyle(
                      fontWeight: isHeader
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    child: Html(
                      data: cell.innerHtml,
                      style: _buildHtmlStyles(theme),
                    ),
                  ),
                ),
              );
            }
            tableRows.add(TableRow(children: tableCells));
            if (row.parent?.localName == 'tbody') isEven = !isEven;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 16.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Table(
                border: TableBorder.all(
                  color: theme.scaffoldBackgroundColor,
                  width: 2,
                ),
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                defaultColumnWidth: const FlexColumnWidth(1.0),
                children: tableRows,
              ),
            ),
          );
        },
      ),
      TagExtension(
        tagsToExtend: {"munnin-checkbox"},
        builder: (extensionContext) {
          final idStr = extensionContext.attributes['id'];
          final state = extensionContext.attributes['state'] ?? ' ';
          final id = int.tryParse(idStr ?? '') ?? -1;

          IconData iconData;
          Color iconColor;

          if (state == 'v') {
            iconData = Icons.check_box;
            iconColor = Colors.green;
          } else if (state == 'x') {
            iconData = Icons.disabled_by_default;
            iconColor = Colors.red;
          } else if (state == '*') {
            iconData = Icons.disabled_by_default;
            iconColor = theme.colorScheme.primary;
          } else {
            iconData = Icons.check_box_outline_blank;
            iconColor = theme.colorScheme.primary;
          }

          return GestureDetector(
            onTap: () {
              if (onCheckboxToggled != null) {
                onCheckboxToggled(id, state == '*' ? ' ' : '*');
              }
            },
            onDoubleTap: () {
              if (onCheckboxToggled != null) {
                onCheckboxToggled(id, state == 'v' ? ' ' : 'v');
              }
            },
            onSecondaryTap: () {
              if (onCheckboxToggled != null) {
                onCheckboxToggled(id, state == 'x' ? ' ' : 'x');
              }
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Icon(iconData, size: 18, color: iconColor),
              ),
            ),
          );
        },
      ),
      TagExtension(
        tagsToExtend: {"munnin-img"},
        builder: (extensionContext) {
          final src = extensionContext.attributes['src'] ?? '';
          final alt = extensionContext.attributes['alt'] ?? '';
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.tertiary, width: 2),
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
            ),
            child: Row(
              children: [
                Icon(Icons.download, color: theme.colorScheme.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Image spéciale : $alt\n($src)',
                    style: TextStyle(color: theme.colorScheme.tertiary),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      TagExtension(
        tagsToExtend: {"img"},
        builder: (extensionContext) {
          final src = extensionContext.attributes['src'];
          final alt = extensionContext.attributes['alt'] ?? '';
          return _buildImageWidget(src, alt, theme);
        },
      ),
      TagExtension(
        tagsToExtend: {"blockquote"},
        builder: (extensionContext) {
          final element = extensionContext.element;
          if (element == null) return const SizedBox.shrink();

          String html = element.innerHtml;

          final regexStandard = RegExp(
            r'^(\s*<p>\s*)?\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION|DANGER)\]([^\n<]*)(.*)',
            dotAll: true,
            caseSensitive: false,
          );
          final regexCustom = RegExp(
            r'^(\s*<p>\s*)?\[!\{(.*?)\}\{(.*?)\}\{(.*?)\}\](.*)',
            dotAll: true,
          );

          final matchCustom = regexCustom.firstMatch(html);
          if (matchCustom != null) {
            final prefix = matchCustom.group(1) ?? '';
            final iconStr = matchCustom.group(2) ?? '';
            final title = matchCustom.group(3)?.trim() ?? '';
            final colorStr = matchCustom.group(4) ?? '';
            final remaining = matchCustom.group(5) ?? '';

            final newHtml = prefix + remaining;
            final color = parseColor(
              colorStr,
              fallback: theme.colorScheme.primary,
            );
            final icon = parseIcon(iconStr);

            return _buildAdmonitionWidget(
              context: context,
              theme: theme,
              color: color,
              icon: icon,
              title: title.isNotEmpty ? title : 'Remarque',
              htmlContent: newHtml,
              filePath: filePath,
              onCheckboxToggled: onCheckboxToggled,
            );
          }

          final matchStd = regexStandard.firstMatch(html);
          if (matchStd != null) {
            final prefix = matchStd.group(1) ?? '';
            final type = matchStd.group(2)!.toUpperCase();
            final title = matchStd.group(3)?.trim() ?? '';
            final remaining = matchStd.group(4) ?? '';

            final newHtml = prefix + remaining;

            Color color = theme.colorScheme.primary;
            IconData icon = LucideIcons.info;
            String defaultTitle = type;

            switch (type) {
              case 'NOTE':
                color = Colors.blue;
                icon = LucideIcons.info;
                break;
              case 'TIP':
                color = Colors.green;
                icon = LucideIcons.lightbulb;
                break;
              case 'IMPORTANT':
                color = Colors.purple;
                icon = LucideIcons.circle_alert;
                break;
              case 'WARNING':
                color = Colors.orange;
                icon = LucideIcons.triangle_alert;
                break;
              case 'CAUTION':
              case 'DANGER':
                color = Colors.red;
                icon = LucideIcons.octagon;
                break;
            }

            return _buildAdmonitionWidget(
              context: context,
              theme: theme,
              color: color,
              icon: icon,
              title: title.isNotEmpty ? title : defaultTitle,
              htmlContent: newHtml,
              filePath: filePath,
              onCheckboxToggled: onCheckboxToggled,
            );
          }

          // Standard blockquote fallback
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: theme.colorScheme.primary, width: 4),
              ),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Html(
              data: html,
              style: _buildHtmlStyles(theme),
              extensions: _buildHtmlExtensions(
                context,
                theme,
                filePath,
                onCheckboxToggled,
              ),
            ),
          );
        },
      ),
    ];
  }

  Widget _buildAdmonitionWidget({
    required BuildContext context,
    required ThemeData theme,
    required Color color,
    required IconData icon,
    required String title,
    required String htmlContent,
    required String filePath,
    void Function(int, String)? onCheckboxToggled,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border(left: BorderSide(color: color, width: 4)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 12,
              top: 12,
              right: 12,
              bottom: 4,
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            child: Html(
              data: htmlContent,
              style: _buildHtmlStyles(theme),
              extensions: _buildHtmlExtensions(
                context,
                theme,
                filePath,
                onCheckboxToggled,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String? src, String alt, ThemeData theme) {
    if (src == null || src.isEmpty) {
      return const SizedBox.shrink();
    }

    // Image Web
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        errorBuilder: (context, error, stackTrace) =>
            _buildErrorImage(src, theme),
      );
    }

    // Image locale
    String imagePath = src;
    if (filePath != null &&
        !File(src).isAbsolute &&
        !src.startsWith('file://')) {
      // Si on a un chemin racine, on résout le chemin relatif proprement
      final parentDir = File(filePath!).parent.path;
      // Ajoute le séparateur à la fin pour que Uri.resolve fonctionne comme un dossier
      final dirUri = Uri.file(parentDir + Platform.pathSeparator);
      imagePath = dirUri.resolve(src).toFilePath();
    } else if (src.startsWith('file://')) {
      imagePath = Uri.parse(src).toFilePath();
    }

    final file = File(imagePath);
    if (file.existsSync()) {
      return Image.file(
        file,
        errorBuilder: (context, error, stackTrace) =>
            _buildErrorImage(src, theme),
      );
    } else {
      return _buildErrorImage(src, theme);
    }
  }

  Widget _buildErrorImage(String src, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.error),
        borderRadius: BorderRadius.circular(4),
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Text(
            "Image introuvable : $src",
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
