import 'dart:math';

import 'package:appflowy/core/helpers/url_launcher.dart';
import 'package:appflowy/generated/flowy_svgs.g.dart';
import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/copy_and_paste/clipboard_service.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/mention/mention_page_block.dart';
import 'package:appflowy/plugins/document/presentation/editor_plugins/toolbar_item/custom_link_toolbar_item.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/workspace/application/view/view_service.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'link_create_menu.dart';
import 'link_edit_menu.dart';
import 'link_styles.dart';

class LinkHoverTrigger extends StatefulWidget {
  const LinkHoverTrigger({
    super.key,
    required this.editorState,
    required this.selection,
    required this.node,
    required this.attribute,
    required this.size,
    this.delayToShow = const Duration(milliseconds: 50),
    this.delayToHide = const Duration(milliseconds: 300),
  });

  final EditorState editorState;
  final Selection selection;
  final Node node;
  final Attributes attribute;
  final Size size;
  final Duration delayToShow;
  final Duration delayToHide;

  @override
  State<LinkHoverTrigger> createState() => _LinkHoverTriggerState();
}

class _LinkHoverTriggerState extends State<LinkHoverTrigger> {
  final hoverMenuController = PopoverController();
  final editMenuController = PopoverController();
  bool isHoverMenuShowing = false;
  bool isHoverMenuHovering = false;
  bool isHoverTriggerHovering = false;

  Size get size => widget.size;

  EditorState get editorState => widget.editorState;

  Selection get selection => widget.selection;

  Attributes get attribute => widget.attribute;

  @override
  void dispose() {
    hoverMenuController.close();
    editMenuController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (v) {
        isHoverTriggerHovering = true;
        Future.delayed(widget.delayToShow, () {
          if (isHoverTriggerHovering && !isHoverMenuShowing) {
            showLinkHoverMenu();
          }
        });
      },
      onExit: (v) {
        isHoverTriggerHovering = false;
        tryToDismissLinkHoverMenu();
      },
      child: buildHoverPopover(
        buildEditPopover(
          Container(
            color: Colors.black.withAlpha(1),
            width: size.width,
            height: size.height,
          ),
        ),
      ),
    );
  }

  Widget buildHoverPopover(Widget child) {
    return AppFlowyPopover(
      controller: hoverMenuController,
      direction: PopoverDirection.topWithLeftAligned,
      offset: Offset(0, size.height),
      onOpen: () {
        keepEditorFocusNotifier.increase();
        isHoverMenuShowing = true;
      },
      onClose: () {
        keepEditorFocusNotifier.decrease();
        isHoverMenuShowing = false;
      },
      margin: EdgeInsets.zero,
      constraints: BoxConstraints(
        maxWidth: max(320, size.width),
        maxHeight: 48 + size.height,
      ),
      decorationColor: Colors.transparent,
      popoverDecoration: BoxDecoration(),
      popupBuilder: (context) => LinkHoverMenu(
        attribute: widget.attribute,
        triggerSize: size,
        onEnter: (_) {
          isHoverMenuHovering = true;
        },
        onExit: (_) {
          isHoverMenuHovering = false;
          tryToDismissLinkHoverMenu();
        },
        onOpenLink: openLink,
        onCopyLink: copyLink,
        onEditLink: showLinkEditMenu,
        onRemoveLink: () => removeLink(editorState, selection, true),
      ),
      child: child,
    );
  }

  Widget buildEditPopover(Widget child) {
    final href = attribute.href ?? '',
        isPage = attribute.isPage,
        title = editorState.getTextInSelection(selection).join();
    return AppFlowyPopover(
      controller: editMenuController,
      direction: PopoverDirection.bottomWithLeftAligned,
      offset: Offset(0, 0),
      onOpen: () => keepEditorFocusNotifier.increase(),
      onClose: () => keepEditorFocusNotifier.decrease(),
      margin: EdgeInsets.zero,
      asBarrier: true,
      decorationColor: Colors.transparent,
      popoverDecoration: BoxDecoration(),
      constraints: BoxConstraints(
        maxWidth: 400,
        minHeight: 282,
      ),
      popupBuilder: (context) => LinkEditMenu(
        linkInfo: LinkInfo(name: title, link: href, isPage: isPage),
        onDismiss: () => editMenuController.close(),
        onApply: (info) async {
          final transaction = editorState.transaction;
          transaction.replaceText(
            widget.node,
            selection.startIndex,
            selection.length,
            info.name,
            attributes: info.toAttribute(),
          );
          editMenuController.close();
          await editorState.apply(transaction);
        },
        onRemoveLink: () => removeLink(editorState, selection, true),
      ),
      child: child,
    );
  }

  void showLinkHoverMenu() {
    if (isHoverMenuShowing) return;
    keepEditorFocusNotifier.increase();
    hoverMenuController.show();
  }

  void showLinkEditMenu() {
    keepEditorFocusNotifier.increase();
    hoverMenuController.close();
    editMenuController.show();
  }

  void tryToDismissLinkHoverMenu() {
    Future.delayed(widget.delayToHide, () {
      if (isHoverMenuHovering || isHoverTriggerHovering) {
        return;
      }
      hoverMenuController.close();
    });
  }

  Future<void> openLink() async {
    final href = widget.attribute.href ?? '', isPage = widget.attribute.isPage;

    if (isPage) {
      final viewId = href.split('/').lastOrNull ?? '';
      if (viewId.isEmpty) {
        await afLaunchUrlString(href);
      } else {
        final (view, isInTrash, isDeleted) =
            await ViewBackendService.getMentionPageStatus(viewId);
        if (view != null) {
          await handleMentionBlockTap(context, widget.editorState, view);
        }
      }
    } else {
      await afLaunchUrlString(href);
    }
  }

  Future<void> copyLink() async {
    final href = widget.attribute.href ?? '';
    if (href.isEmpty) return;
    await getIt<ClipboardService>()
        .setData(ClipboardServiceData(plainText: href));
    hoverMenuController.close();
  }
}

class LinkHoverMenu extends StatelessWidget {
  const LinkHoverMenu({
    super.key,
    required this.attribute,
    required this.onEnter,
    required this.onExit,
    required this.triggerSize,
    required this.onCopyLink,
    required this.onOpenLink,
    required this.onEditLink,
    required this.onRemoveLink,
  });

  final Attributes attribute;
  final PointerEnterEventListener onEnter;
  final PointerExitEventListener onExit;
  final Size triggerSize;
  final VoidCallback onCopyLink;
  final VoidCallback onOpenLink;
  final VoidCallback onEditLink;
  final VoidCallback onRemoveLink;

  @override
  Widget build(BuildContext context) {
    final href = attribute.href ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          onEnter: onEnter,
          onExit: onExit,
          child: SizedBox(
            width: max(320, triggerSize.width),
            height: 48,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 320,
                height: 48,
                decoration: buildToolbarLinkDecoration(context),
                padding: EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: FlowyText.regular(
                        href,
                        fontSize: 14,
                        figmaLineHeight: 20,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      height: 20,
                      width: 1,
                      color: LinkStyle.borderColor,
                      margin: EdgeInsets.symmetric(horizontal: 6),
                    ),
                    FlowyIconButton(
                      icon: FlowySvg(FlowySvgs.toolbar_link_m),
                      tooltipText: LocaleKeys.editor_copyLink.tr(),
                      width: 36,
                      height: 32,
                      onPressed: onCopyLink,
                    ),
                    FlowyIconButton(
                      icon: FlowySvg(FlowySvgs.toolbar_link_edit_m),
                      tooltipText: LocaleKeys.editor_editLink.tr(),
                      width: 36,
                      height: 32,
                      onPressed: onEditLink,
                    ),
                    FlowyIconButton(
                      icon: FlowySvg(FlowySvgs.toolbar_link_unlink_m),
                      tooltipText: LocaleKeys.editor_removeLink.tr(),
                      width: 36,
                      height: 32,
                      onPressed: onRemoveLink,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: onEnter,
          onExit: onExit,
          child: GestureDetector(
            onTap: onOpenLink,
            child: Container(
              width: triggerSize.width,
              height: triggerSize.height,
              color: Colors.black.withAlpha(1),
            ),
          ),
        ),
      ],
    );
  }
}
