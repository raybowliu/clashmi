// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:clashmi/screens/group_item_options.dart';
import 'package:clashmi/screens/themes.dart';
import 'package:flutter/material.dart';
import 'package:after_layout/after_layout.dart';
import 'package:clashmi/screens/dialog_utils.dart';
import 'package:clashmi/screens/group_item_creator.dart';
import 'package:clashmi/screens/theme_config.dart';
import 'package:clashmi/screens/widgets/framework.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class GroupScreen extends LasyRenderingStatefulWidget {
  static RouteSettings routSettings(String viewTag) {
    return RouteSettings(name: "GroupScreen:$viewTag");
  }

  final String title;
  final Future<List<GroupItem>> Function(
      BuildContext context, SetStateCallback? setstate) getOptions;
  final bool hasReturn;
  final Future<bool> Function(BuildContext context)? onDone;
  final String? tipsIfNoOnDone;
  final IconData? onDoneIcon;
  final Future<void> Function(BuildContext context)? onFirstLayout;
  const GroupScreen(
      {super.key,
      required this.title,
      required this.getOptions,
      this.hasReturn = true,
      this.onDone,
      this.tipsIfNoOnDone,
      this.onDoneIcon,
      this.onFirstLayout});

  @override
  State<GroupScreen> createState() => GroupScreenState();
}

class GroupScreenState extends LasyRenderingState<GroupScreen>
    with AfterLayoutMixin {
  static int _adsCount = 0;
  bool _hasAds = false;
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    if (_hasAds) {
      --GroupScreenState._adsCount;
      _hasAds = false;
    }

    super.dispose();
  }

  @override
  FutureOr<void> afterFirstLayout(BuildContext context) async {
    if (widget.onFirstLayout != null) {
      widget.onFirstLayout!.call(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    Size windowSize = MediaQuery.of(context).size;
    var themes = Provider.of<Themes>(context, listen: false);
    Color? color = themes.getThemeHomeColor(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.zero,
        child: AppBar(
          backgroundColor: color,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: color,
          ),
        ),
      ),
      backgroundColor: color,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    !widget.hasReturn
                        ? const SizedBox(
                            width: 50,
                          )
                        : InkWell(
                            onTap: () => Navigator.pop(context),
                            child: const SizedBox(
                              width: 50,
                              height: 30,
                              child: Icon(
                                Icons.arrow_back_ios_outlined,
                                size: 26,
                              ),
                            ),
                          ),
                    SizedBox(
                      width: windowSize.width - 50 * 2,
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: ThemeConfig.kFontWeightTitle,
                            fontSize: ThemeConfig.kFontSizeTitle),
                      ),
                    ),
                    widget.onDone != null
                        ? InkWell(
                            onTap: () async {
                              if (await widget.onDone!(context)) {
                                Navigator.pop(context, true);
                              }
                              setState(() {});
                            },
                            child: SizedBox(
                              width: 50,
                              height: 30,
                              child: Icon(
                                widget.onDoneIcon ?? Icons.done_outlined,
                                size: 26,
                              ),
                            ),
                          )
                        : widget.tipsIfNoOnDone != null &&
                                widget.tipsIfNoOnDone!.isNotEmpty
                            ? Tooltip(
                                message: widget.tipsIfNoOnDone,
                                child: InkWell(
                                  onTap: () {
                                    DialogUtils.showAlertDialog(
                                        context, widget.tipsIfNoOnDone!);
                                  },
                                  child: const SizedBox(
                                      width: 50,
                                      height: 30,
                                      child: Icon(
                                        Icons.info_outlined,
                                        size: 20,
                                      )),
                                ))
                            : const SizedBox(
                                width: 50,
                              ),
                  ],
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
                  child: SingleChildScrollView(
                    child: FutureBuilder(
                      future: getGroupOptionsWithTryCatch(),
                      builder: (BuildContext context,
                          AsyncSnapshot<List<GroupItem>> snapshot) {
                        List<GroupItem> data =
                            snapshot.hasData ? snapshot.data! : [];
                        List<Widget> children = [];

                        children.addAll(
                            GroupItemCreator.createGroups(context, data));
                        return Column(children: children);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<GroupItem>> getGroupOptionsWithTryCatch() async {
    try {
      return await getGroupOptions();
    } catch (err, stacktrace) {
      if (!mounted) {
        return [];
      }
      DialogUtils.showAlertDialog(
          context, "${err.toString()}\n${stacktrace.toString()}",
          showCopy: true, showFAQ: true, withVersion: true);
      return [];
    }
  }

  Future<List<GroupItem>> getGroupOptions() async {
    var groups = await widget.getOptions(context, () {
      setState(() {});
    });
    for (var group in groups) {
      for (var option in group.options) {
        if ((option.textOptions != null) &&
            (option.textOptions!.onPush != null)) {
          var callback = option.textOptions!.onPush;
          option.textOptions!.onPush = () async {
            await callback!();
            if (!mounted) {
              return;
            }
            setState(() {});
          };
        } else if ((option.switchOptions != null) &&
            (option.switchOptions!.onSwitch != null)) {
          var callback = option.switchOptions!.onSwitch;
          option.switchOptions!.onSwitch = (bool value) async {
            await callback!(value);
            if (!mounted) {
              return;
            }
            setState(() {});
          };
        } else if ((option.pushOptions != null) &&
            (option.pushOptions!.onPush != null)) {
          var callback = option.pushOptions!.onPush;
          option.pushOptions!.onPush = () async {
            await callback!();
            if (!mounted) {
              return;
            }
            setState(() {});
          };
        } else if ((option.timerIntervalPickerOptions != null) &&
            (option.timerIntervalPickerOptions!.onPicker != null)) {
          var callback = option.timerIntervalPickerOptions!.onPicker;
          option.timerIntervalPickerOptions!.onPicker =
              (bool canceled, Duration? value) async {
            await callback!(canceled, value);
            if (!mounted) {
              return;
            }
            setState(() {});
          };
        } else if ((option.stringPickerOptions != null) &&
            (option.stringPickerOptions!.onPicker != null)) {
          var callback = option.stringPickerOptions!.onPicker;
          option.stringPickerOptions!.onPicker = (String? value) async {
            await callback!(value);
            if (!mounted) {
              return;
            }
            setState(() {});
          };
        }
      }
    }

    return groups;
  }
}
