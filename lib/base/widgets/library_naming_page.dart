import 'dart:async';

import 'package:lain/base/app.dart';
import 'package:lain/base/data/library_naming.dart';
import 'package:lain/base/data/setting.dart';
import 'package:lain/base/services/color_manager.dart';
import 'package:lain/base/services/interaction.dart';
import 'package:lain/base/widgets/apple_form.dart';
import 'package:lain/base/widgets/local_music_page.dart';
import 'package:lain/l10n/generated/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

/// The folder and file name templates used when organizing a local library.
///
/// Every change is written as it is typed, the way the rest of the app's
/// settings work; an invalid template is explained instead of silently kept.
class LibraryNamingPage extends StatefulWidget {
  const LibraryNamingPage({super.key});

  @override
  State<LibraryNamingPage> createState() => _LibraryNamingPageState();
}

class _LibraryNamingPageState extends State<LibraryNamingPage> {
  late final TextEditingController _dirController;
  late final TextEditingController _fileController;
  final ValueNotifier<bool> _keepFeat = ValueNotifier(true);
  Timer? _debounce;

  NamingTemplateError? _dirError;
  NamingTemplateError? _fileError;
  LibraryNamingPlan? _plan;

  @override
  void initState() {
    super.initState();
    _dirController = TextEditingController(
      text: libraryDirTemplateNotifier.value,
    );
    _fileController = TextEditingController(
      text: libraryFileTemplateNotifier.value,
    );
    _keepFeat.value = libraryKeepFeatNotifier.value;
    _dirController.addListener(_onChanged);
    _fileController.addListener(_onChanged);
    _keepFeat.addListener(_onChanged);
    _evaluate();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _dirController.dispose();
    _fileController.dispose();
    _keepFeat.dispose();
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) {
        return;
      }
      _evaluate();
    });
  }

  void _evaluate() {
    final dirError = validateNamingTemplate(
      _dirController.text,
      directory: true,
    );
    final fileError = validateNamingTemplate(
      _fileController.text,
      directory: false,
    );
    final format = LibraryNamingFormat(
      dirTemplate: _dirController.text,
      fileTemplate: _fileController.text,
      keepFeat: _keepFeat.value,
    );
    final plan = dirError == null && fileError == null
        ? buildLibraryNamingPlan(format, namingExampleInput)
        : null;
    setState(() {
      _dirError = dirError;
      _fileError = fileError;
      _plan = plan;
    });
    if (dirError == null && fileError == null) {
      libraryDirTemplateNotifier.value = _dirController.text;
      libraryFileTemplateNotifier.value = _fileController.text;
      libraryKeepFeatNotifier.value = _keepFeat.value;
      setting.save();
    }
  }

  String? _errorText(AppLocalizations l10n, NamingTemplateError? error) {
    if (error == null) {
      return null;
    }
    return switch (error) {
      NamingTemplateError.empty => l10n.templateEmpty,
      NamingTemplateError.missingTitle => l10n.templateNeedsTitle,
      NamingTemplateError.absolutePath => l10n.templateAbsolute,
      NamingTemplateError.parentSegment => l10n.templateParentSegment,
      NamingTemplateError.unknownPlaceholder => l10n.templateUnknownPlaceholder,
    };
  }

  Future<void> _restoreDefaults() async {
    final l10n = AppLocalizations.of(context);
    if (!await showConfirmDialog(context, l10n.restoreDefaultFormat)) {
      return;
    }
    _dirController.text = defaultLibraryDirTemplate;
    _fileController.text = defaultLibraryFileTemplate;
    _keepFeat.value = true;
    _evaluate();
  }

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 4, 32, 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: colorManager.getSpecificTextColor().withAlpha(150),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(isLocalLibrary);
    final l10n = AppLocalizations.of(context);
    final textColor = colorManager.getSpecificTextColor();
    final example = namingExampleInput;
    final plan = _plan;

    return opaqueSettingsPage(
      context: context,
      title: l10n.namingFormat,
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 100),
        children: [
          appleSectionTitle(l10n.directorySection),
          AppleFormSection(
            children: [
              appleTextFieldRow(
                l10n.directoryTemplate,
                _dirController,
                placeholder: defaultLibraryDirTemplate,
                textAlign: TextAlign.start,
              ),
            ],
          ),
          _hint(
            _errorText(l10n, _dirError) ??
                l10n.namingPlaceholders(
                  libraryNamingPlaceholderNames.join(', '),
                ),
          ),
          appleSectionTitle(l10n.filenameSection),
          AppleFormSection(
            children: [
              appleTextFieldRow(
                l10n.filenameTemplate,
                _fileController,
                placeholder: defaultLibraryFileTemplate,
                textAlign: TextAlign.start,
              ),
              appleSwitchRow(l10n.keepFeat, _keepFeat),
            ],
          ),
          _hint(
            _errorText(l10n, _fileError) ??
                l10n.namingSlashHelp,
          ),
          appleSectionTitle(l10n.previewSection),
          AppleFormSection(
            divided: false,
            children: [
              appleFormRow(
                l10n.exampleSong,
                Text(
                  '${example.artist} - ${example.title}',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: textColor),
                ),
              ),
              appleFormRow(
                l10n.currentPath,
                SelectableText(
                  p.join('Artist', 'Album', '${example.fileName}${example.ext}'),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, color: textColor.withAlpha(200)),
                ),
              ),
              appleFormRow(
                l10n.organizedPath,
                SelectableText(
                  plan == null
                      ? l10n.invalidTemplate
                      : p.join(
                          plan.relativeDir.isEmpty ? '' : plan.relativeDir,
                          plan.fileName,
                        ),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 13, color: textColor),
                ),
              ),
            ],
          ),
          AppleFormSection(
            divided: false,
            children: [
              ListTile(
                leading: Icon(
                  Icons.restart_alt_rounded,
                  size: 30,
                  color: iconColor.value,
                ),
                title: Text(l10n.restoreDefaultFormat),
                onTap: _restoreDefaults,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
