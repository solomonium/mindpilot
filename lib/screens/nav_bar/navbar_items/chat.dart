import 'package:flutter/services.dart';
import 'package:mindpilot/export.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  final Map<int, Color> _bubbleColors = {};

  @override
  void initState() {
    super.initState();
    AppHelper.setScreenshotProtection(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().initChat();
    });
  }

  @override
  void dispose() {
    // AppHelper.setScreenshotProtection(false);
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final chatStore = context.read<ChatProvider>();
    final isPro = context.read<AppAuthProvider>().isPro;

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (!chatStore.canSendMessage(isPro)) {
      AppHelper.showPaywall(context, feature: 'Unlimited AI Chat');
      return;
    }

    chatStore.addMessage(text, true);
    _messageController.clear();
    _scrollToBottom();

    setState(() => _isLoading = true);

    final prompt =
        """
You are a helpful and supportive AI assistant for the **MindPilot** app.
Your goal is to assist users with their questions, provide guidance on productivity, and offer mental clarity.

IMPORTANT:
1. If the user's question relates to their personalized focus areas (like productivity, mental clarity, etc.), you MUST suggest using the **Decision Analyzer** (for making better choices) and/or **Focus Sessions** (for improving concentration).
2. If the question is not related to these goals, respond naturally without suggesting these tools.
3. Keep your responses friendly, supportive, and clear.

User: $text
""";

    try {
      final response = await chatStore.geminiService.sendMessage(prompt);

      if (mounted) {
        chatStore.incrementMessageCount();
        chatStore.addMessage(
          response ?? "I'm sorry, I couldn't process that.",
          false,
        );
        _scrollToBottom();
      }
    } catch (e) {
      safePrint('AI Error: $e');
      if (mounted) {
        context.showInAppNotification(
          "I'm sorry, I am unable to connect right now, please try after sometine. Thank you ", // 'AI Error: $e',
          type: InAppNotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final chatStore = context.watch<ChatProvider>();
    final isPro = context.watch<AppAuthProvider>().isPro;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PrimaryText(
              text: 'My Personal Assistant',
              color: theme.accentTxt,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            if (!isPro)
              SecondaryText(
                text:
                    '${chatStore.freemiumLimit - chatStore.dailyMessageCount} messages left today',
                color: theme.accentTxt.withOpacity(0.5),
                fontSize: 10,
              ),
          ],
        ),
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Icon(
            Icons.chevron_left,
            color: theme.accentTxt,
          ).rippleClick(() => context.pop()),
        ),
        actions: [
          Icon(Icons.refresh, color: theme.accentTxt).rippleClick(() {
            chatStore.resetChat();
          }),
          10.horizontalSpace,
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.15,
              child: Image.asset(R.png.loginBg.png, fit: BoxFit.cover),
            ),
          ),
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: theme.primaryBase.withOpacity(0.05),
                child: Center(
                  child: SecondaryText(
                    text:
                        '💡 Tip: Tap the color circles above a message to change its text color.',
                    fontSize: 10,
                    color: theme.accentTxt.withOpacity(0.6),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  itemCount: chatStore.messages.length,
                  itemBuilder: (context, index) {
                    final message = chatStore.messages[index];
                    return _chatBubble(
                      context,
                      message['text'],
                      message['isMe'],
                      index,
                    );
                  },
                ),
              ),
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              _messageInput(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _copyIcon(BuildContext context, String text) {
    AppTheme theme = context.watch();
    return Icon(
      Icons.copy_rounded,
      color: theme.accentTxt.withOpacity(0.4),
      size: 16,
    ).rippleClick(() async {
      final isPro = context.read<AppAuthProvider>().isPro;
      if (!isPro) {
        AppHelper.showPaywall(context, feature: 'Copy AI Response');
        return;
      }
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        context.showInAppNotification(
          "Message copied to clipboard!",
          type: InAppNotificationType.success,
        );
      }
    });
  }

  Widget _chatBubble(BuildContext context, String text, bool isMe, int index) {
    AppTheme theme = context.watch();
    final textColor = isMe
        ? Colors.white
        : (_bubbleColors[index] ?? theme.accentTxt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.75,
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 6, right: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _colorPicker(
                          index,
                          const Color(0xFFC0FF00),
                        ), // Lemon Green
                        8.horizontalSpace,
                        _colorPicker(index, const Color(0xFFFF914D)), // Orange
                        8.horizontalSpace,
                        _colorPicker(
                          index,
                          theme.accentTxt,
                          isReset: true,
                        ), // Reset
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _copyIcon(context, text),
                        12.horizontalSpace,
                        _shareIcon(context, text, index),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          GestureDetector(
            onLongPress: () async {
              if (!isMe) {
                final isPro = context.read<AppAuthProvider>().isPro;
                if (!isPro) {
                  AppHelper.showPaywall(context, feature: 'Copy AI Response');
                  return;
                }
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  context.showInAppNotification(
                    "Message copied to clipboard!",
                    type: InAppNotificationType.success,
                  );
                }
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: isMe
                    ? theme.primaryBase
                    : theme.accentTxt.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 16),
                ),
                border: isMe
                    ? null
                    : Border.all(color: theme.accentTxt.withOpacity(0.1)),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 0),
                    child: MarkdownBody(
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: textColor, fontSize: 16),
                        strong: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        h1: TextStyle(
                          color: textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        h2: TextStyle(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        h3: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        listBullet: TextStyle(color: textColor, fontSize: 16),
                        tableBody: TextStyle(color: textColor, fontSize: 14),
                        tableHead: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                        tableBorder: TableBorder.all(
                          color: textColor.withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shareIcon(BuildContext context, String text, int index) {
    AppTheme theme = context.watch();
    final isPro = context.read<AppAuthProvider>().isPro;
    return Icon(
      Icons.share_outlined,
      color: theme.accentTxt.withOpacity(0.4),
      size: 16,
    ).rippleClick(() {
      if (!isPro) {
        AppHelper.showPaywall(context, feature: 'Share Chat Highlight');
        return;
      }
      final chatStore = context.read<ChatProvider>();
      final user = context.read<AppAuthProvider>().user;

      String? userMsg;
      if (index > 0 && chatStore.messages[index - 1]['isMe']) {
        userMsg = chatStore.messages[index - 1]['text'];
      }

      final downloadUrl = ConfigService().updateUrl;
      ShareService.captureAndShare(
        context,
        text:
            "MindPilot AI Wisdom! 🧠✨ My personal assistant keeps me sharp. Join me!\n\nDownload: $downloadUrl\n#MindPilot #AI",
        widget: ShareableCard(
          mode: ShareableCardMode.chat,
          chatUserMessage: userMsg,
          chatAiResponse: text,
          userName: user?.displayName,
        ),
      );
    });
  }

  Widget _colorPicker(int index, Color color, {bool isReset = false}) {
    final isPro = context.read<AppAuthProvider>().isPro;
    return GestureDetector(
      onTap: () {
        if (!isPro) {
          AppHelper.showPaywall(context, feature: 'Chat Customization');
          return;
        }
        setState(() {
          _bubbleColors[index] = color;
        });
      },
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 0.5),
        ),
        child: isReset
            ? const Icon(Icons.refresh, size: 10, color: Colors.black)
            : null,
      ),
    );
  }

  Widget _messageInput(BuildContext context) {
    AppTheme theme = context.watch();
    final isPro = context.read<AppAuthProvider>().isPro;
    final chatStore = context.read<ChatProvider>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: theme.brandDark,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickActionChip(context, '👋 Hello!'),
                8.horizontalSpace,
                _quickActionChip(context, '😊 How are you?'),
                8.horizontalSpace,
                _quickActionChip(context, '🚀 Tell me about MindPilot'),
                8.horizontalSpace,
                _quickActionChip(context, '💡 Give me a tip'),
              ],
            ),
          ),
          16.verticalSpace,
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: theme.accentTxt.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: theme.accentTxt, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: isPro || chatStore.canSendMessage(false)
                          ? 'Type your message...'
                          : 'Upgrade to send more messages',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: theme.accentTxt.withOpacity(0.5),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
              12.horizontalSpace,
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryBase,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryBase.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 20),
              ).rippleClick(_sendMessage),
            ],
          ),
        ],
      ),
    );
  }

  Widget _quickActionChip(BuildContext context, String text) {
    AppTheme theme = context.watch();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.accentTxt.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.accentTxt.withOpacity(0.1)),
      ),
      child: SecondaryText(
        text: text,
        fontSize: 12,
        color: theme.accentTxt.withOpacity(0.8),
      ),
    ).rippleClick(() {
      setState(() {
        _messageController.text = text;
        _messageController.selection = TextSelection.fromPosition(
          TextPosition(offset: _messageController.text.length),
        );
      });
    });
  }
}
