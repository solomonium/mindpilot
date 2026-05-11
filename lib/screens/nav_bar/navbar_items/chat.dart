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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().initChat();
    });
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
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    chatStore.addMessage(text, true);
    _messageController.clear();
    _scrollToBottom();

    setState(() => _isLoading = true);

    // Simple chat prompt without ChatProcessor logic
    final prompt =
        """
You are a helpful and supportive AI assistant for the MindPilot app. 
Respond to the user's message in a clear and friendly manner.
Use markdown for formatting.

User: $text
""";

    final response = await chatStore.geminiService.sendMessage(prompt);

    if (mounted) {
      setState(() => _isLoading = false);
      chatStore.addMessage(
        response ?? "I'm sorry, I couldn't process that.",
        false,
      );
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = context.watch();
    final chatStore = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: PrimaryText(
          text: 'My Personal Assistant',
          color: theme.accentTxt,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: false,
        leading: Icon(
          Icons.chevron_left,
          color: theme.accentTxt,
        ).rippleClick(() => context.pop()),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: chatStore.selectedModel,
              dropdownColor: theme.brandDark,
              icon: Icon(Icons.arrow_drop_down, color: theme.accentTxt),
              items: chatStore.availableModels.map((String model) {
                return DropdownMenuItem<String>(
                  value: model,
                  child: SecondaryText(
                    text: model.replaceAll('gemini-', '').toUpperCase(),
                    color: theme.accentTxt,
                    fontSize: 12,
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) chatStore.updateModel(val);
              },
            ),
          ),
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
          SelectionArea(
            child: Column(
              children: [
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
          ),
        ],
      ),
    );
  }

  Widget _chatBubble(BuildContext context, String text, bool isMe) {
    AppTheme theme = context.watch();
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? theme.primaryBase : theme.accentTxt.withOpacity(0.1),
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
        child: MarkdownBody(
          data: text,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: theme.accentTxt, fontSize: 16),
            strong: TextStyle(
              color: theme.accentTxt,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            h1: TextStyle(
              color: theme.accentTxt,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            h2: TextStyle(
              color: theme.accentTxt,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            h3: TextStyle(
              color: theme.accentTxt,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            listBullet: TextStyle(color: theme.accentTxt, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _messageInput(BuildContext context) {
    AppTheme theme = context.watch();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: theme.brandDark,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
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
                onSubmitted: (_) => _sendMessage(),
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: theme.accentTxt, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
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
    );
  }
}
