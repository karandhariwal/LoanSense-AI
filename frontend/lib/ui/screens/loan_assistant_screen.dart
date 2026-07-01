import 'dart:async';
import 'dart:math';

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';
import 'package:loansense_ai/data/models/loan_assistant_models.dart';
import 'package:loansense_ai/data/repositories/loan_repository.dart';
import 'package:loansense_ai/data/repositories/loan_assistant_repository.dart';
import 'package:loansense_ai/data/repositories/http_loan_assistant_repository.dart';
import 'package:loansense_ai/ui/screens/home_dashboard_screen.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _P {
  static const bg        = Color(0xFF131314);
  static const surface   = Color(0xFF1E1E1F);
  static const border    = Color(0xFF2A2A2B);
  static const userBubble= Color(0xFF2A2A40);
  static const txt       = Color(0xFFECECEC);
  static const txtMuted  = Color(0xFF8E8E9A);
  static const accent    = Color(0xFF7C7FD6);
  static const safe      = Color(0xFF6FD080);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class LoanAssistantScreen extends StatefulWidget {
  final LoanAnalysisReport? report;
  final String? loanId;
  final String? targetClauseId;

  const LoanAssistantScreen({
    super.key,
    this.report,
    this.loanId,
    this.targetClauseId,
  });

  @override
  State<LoanAssistantScreen> createState() => _LoanAssistantScreenState();
}

class _LoanAssistantScreenState extends State<LoanAssistantScreen>
    with TickerProviderStateMixin {
  late final LoanAssistantConversationController _controller;
  late final ScrollController _scrollController;
  late final AnimationController _enterController;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  bool _scrollQueued = false;

  @override
  void initState() {
    super.initState();
    _controller = LoanAssistantConversationController(
      report: widget.report,
      loanId: widget.loanId ?? widget.report?.loanId ?? '',
      targetClauseId: widget.targetClauseId,
    );
    if (widget.report == null) {
      _controller.load();
    } else {
      _controller.bootstrap();
    }
    _controller.addListener(_queueScroll);
    _scrollController = ScrollController();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.removeListener(_queueScroll);
    _controller.dispose();
    _scrollController.dispose();
    _enterController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _queueScroll() {
    if (_scrollQueued) return;
    _scrollQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollQueued = false;
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _controller.isSending) return;
    FocusScope.of(context).unfocus();
    _inputController.clear();
    await _controller.sendMessage(text);
  }

  Future<void> _copy(LoanAssistantMessage message) async {
    final text = message.card?.answer ?? message.content;
    await Clipboard.setData(ClipboardData(text: text));
    _toast('Copied to clipboard');
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _P.surface,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _P.border),
        ),
        elevation: 0,
        content: Text(
          text,
          style: GoogleFonts.inter(fontSize: 13, color: _P.txt),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: _P.bg,
      resizeToAvoidBottomInset: false,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
        child: Column(
          children: [
            // ── Top bar
            _TopBar(
              onBack: () {
                HapticFeedback.selectionClick();
                final nav = Navigator.of(context);
                if (nav.canPop()) {
                  nav.maybePop();
                } else {
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
                    (_) => false,
                  );
                }
              },
              controller: _controller,
            ),
            // ── Message list
            Expanded(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (_, __) {
                  if (_controller.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: _P.accent,
                        strokeWidth: 2,
                      ),
                    );
                  }
                  final msgs = _controller.messages;
                  return ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      16, 16, 16,
                      80 + keyboardInset,
                    ),
                    itemCount: msgs.length + (_controller.suggestions.isNotEmpty ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == msgs.length) {
                        return _SuggestionRow(
                          suggestions: _controller.suggestions,
                          onTap: _send,
                        );
                      }
                      final msg = msgs[i];
                      return _AnimatedEntry(
                        fresh: msg.isFresh,
                        child: msg.role == LoanAssistantRole.user
                            ? _UserBubble(message: msg)
                            : _AssistantBubble(
                                message: msg,
                                onCopy: () => _copy(msg),
                              ),
                      );
                    },
                  );
                },
              ),
            ),
            // ── Input bar
            AnimatedPadding(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(bottom: keyboardInset),
              child: _InputBar(
                controller: _inputController,
                focusNode: _inputFocus,
                isSending: _controller.isSending,
                onSend: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final LoanAssistantConversationController controller;

  const _TopBar({required this.onBack, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        decoration: const BoxDecoration(
          color: _P.bg,
          border: Border(bottom: BorderSide(color: _P.border, width: 0.5)),
        ),
        child: Row(
          children: [
            // Back button
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: _P.txt,
            ),
            // Avatar
            const SizedBox(width: 4),
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF5A5CF4), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 10),
            // Title + subtitle
            Expanded(
              child: AnimatedBuilder(
                animation: controller,
                builder: (_, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LoanSense AI',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _P.txt,
                      ),
                    ),
                    Text(
                      controller.isLoading
                          ? 'Connecting...'
                          : controller.contextLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _P.txtMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Online indicator
            Container(
              margin: const EdgeInsets.only(right: 12),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _P.safe,
                boxShadow: [
                  BoxShadow(color: _P.safe.withValues(alpha: 0.5), blurRadius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Animated Entry ───────────────────────────────────────────────────────────
class _AnimatedEntry extends StatelessWidget {
  final bool fresh;
  final Widget child;

  const _AnimatedEntry({required this.fresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: fresh ? 0 : 1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: fresh ? const Offset(0, 0.04) : Offset.zero,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}

// ─── User Bubble ──────────────────────────────────────────────────────────────
class _UserBubble extends StatelessWidget {
  final LoanAssistantMessage message;

  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _P.userBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(color: _P.accent.withValues(alpha: 0.15)),
              ),
              child: Text(
                message.content,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.5,
                  color: _P.txt,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Assistant Bubble ─────────────────────────────────────────────────────────
class _AssistantBubble extends StatelessWidget {
  final LoanAssistantMessage message;
  final VoidCallback onCopy;

  const _AssistantBubble({
    required this.message,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI Avatar
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF5A5CF4), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
          ),
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.state == LoanAssistantMessageState.typing)
                  const _TypingDots()
                else
                  _MessageContent(message: message, onCopy: onCopy),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  final LoanAssistantMessage message;
  final VoidCallback onCopy;

  const _MessageContent({required this.message, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final answer = message.card?.answer ?? message.content;
    final sourceClause = message.card?.sourceClause;
    final pageRef = message.card?.pageReference;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main answer text
        Text(
          answer,
          style: GoogleFonts.inter(
            fontSize: 15,
            height: 1.65,
            color: _P.txt,
          ),
        ),
        // Source / citation pills (if available and not placeholder)
        if (sourceClause != null &&
            sourceClause != 'N/A' &&
            !sourceClause.contains('Analyzing document context') &&
            sourceClause.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CitationCard(sourceClause: sourceClause, pageRef: pageRef),
        ],
        // Action row
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              _formatTime(message.timestamp),
              style: GoogleFonts.inter(fontSize: 11, color: _P.txtMuted),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onCopy,
              child: Row(
                children: [
                  const Icon(Icons.content_copy_rounded, size: 13, color: _P.txtMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: GoogleFonts.inter(fontSize: 11, color: _P.txtMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CitationCard extends StatelessWidget {
  final String sourceClause;
  final String? pageRef;

  const _CitationCard({required this.sourceClause, this.pageRef});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _P.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _P.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote_rounded, size: 13, color: _P.accent),
              const SizedBox(width: 6),
              Text(
                'Source',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _P.accent,
                ),
              ),
              if (pageRef != null && pageRef!.isNotEmpty && pageRef != 'N/A') ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _P.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    pageRef!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _P.accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sourceClause,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              fontStyle: FontStyle.italic,
              color: _P.txtMuted,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Typing Indicator ─────────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          children: List.generate(3, (i) {
            final t = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
            final opacity = (sin(t * pi)).clamp(0.25, 1.0);
            return Container(
              margin: const EdgeInsets.only(right: 5),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _P.txtMuted.withValues(alpha: opacity),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─── Suggestion Row ───────────────────────────────────────────────────────────
class _SuggestionRow extends StatelessWidget {
  final List<LoanAssistantSuggestion> suggestions;
  final ValueChanged<String> onTap;

  const _SuggestionRow({required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: suggestions.map((s) {
            return GestureDetector(
              onTap: () => onTap(s.prompt),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: _P.surface,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _P.border),
                ),
                child: Text(
                  s.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _P.txt,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────
class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final ValueChanged<String> onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  void _onTextChange() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: const BoxDecoration(
          color: _P.bg,
          border: Border(top: BorderSide(color: _P.border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
                decoration: BoxDecoration(
                  color: _P.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _P.border),
                ),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: _P.txt,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ask about your loan...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 15,
                      color: _P.txtMuted,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_hasText && !widget.isSending)
                      ? widget.onSend
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: (_hasText && !widget.isSending)
                    ? const LinearGradient(
                        colors: [Color(0xFF5A5CF4), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: (_hasText && !widget.isSending)
                    ? null
                    : _P.surface,
                border: Border.all(color: _P.border),
              ),
              child: GestureDetector(
                onTap: (_hasText && !widget.isSending)
                    ? () => widget.onSend(widget.controller.text)
                    : null,
                child: Center(
                  child: widget.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: _P.accent,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: _hasText ? Colors.white : _P.txtMuted,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Controller (unchanged logic) ────────────────────────────────────────────
class LoanAssistantConversationController extends ChangeNotifier {
  LoanAnalysisReport? _report;
  final String loanId;
  final String? targetClauseId;
  final LoanAssistantRepository _repository;
  final List<LoanAssistantMessage> _messages = [];
  final Map<String, bool> _expanded = {};
  bool isSending = false;
  bool isListening = false;
  bool hasAttachment = true;
  bool isLoading = true;
  String documentLabel = 'Agreement_V2.pdf';
  String pageLabel = 'Page 14';
  String contextLabel = 'Personalized Loan Analysis';
  List<LoanAssistantSuggestion> suggestions = const [];

  LoanAssistantConversationController({
    LoanAnalysisReport? report,
    required this.loanId,
    this.targetClauseId,
    LoanAssistantRepository? repository,
  })  : _report = report,
        _repository = repository ?? HttpLoanAssistantRepository() {
    if (_report != null) {
      isLoading = false;
    }
  }

  LoanAnalysisReport get report => _report!;

  List<LoanAssistantMessage> get messages => List.unmodifiable(_messages);

  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    if (loanId.isEmpty) {
      developer.log('LoanAssistantConversationController: no loanId provided, skipping fetch.');
      _report = null;
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _report = await LoanRepository().fetchAnalysis(loanId);
    } catch (e) {
      developer.log('Error fetching analysis in assistant: $e');
      _report = _generateFallbackReport(loanId);
    }
    isLoading = false;
    await bootstrap();
  }

  static LoanAnalysisReport _generateFallbackReport(String loanId) {
    return LoanAnalysisReport(
      loanId: loanId,
      lenderName: 'Apex Finance Corp',
      productName: 'Secure Home Prime',
      healthScore: 7.8,
      healthSummary: 'Moderate health. Previewing local fallback report.',
      detailedSummary: 'Detailed analysis is not available offline.',
      simpleSummary: 'Offline mode: Previewing fallback template.',
      recommendedAction: 'Verify connection',
      contractClarity: '90% Transparent',
      metrics: const [],
      alerts: const [],
      sources: const [],
      costSlices: const [],
      emiSeries: const [],
      clauseChips: const [],
      extractions: const [],
    );
  }

  Future<void> bootstrap() async {
    if (_report == null) return;
    final seed = _repository.bootstrap(report);

    List<LoanAssistantMessage> historyMessages = [];
    try {
      historyMessages = await _repository.fetchHistory(loanId);
    } catch (e) {
      developer.log('Error fetching chat history in bootstrap: $e');
    }

    _messages.clear();
    if (historyMessages.isNotEmpty) {
      _messages.addAll(historyMessages);
    } else {
      _messages.addAll(seed.messages);
    }

    suggestions = seed.suggestions;
    documentLabel = seed.documentLabel;
    pageLabel = seed.pageLabel;
    contextLabel = seed.contextLabel;
    for (final message in _messages) {
      if (message.role == LoanAssistantRole.assistant) {
        _expanded[message.id] = true;
      }
      _settleFresh(message.id);
    }
    notifyListeners();
  }

  Future<void> sendMessage(String query) async {
    if (isSending) return;
    final userMessage = LoanAssistantMessage(
      id: _id('user'),
      role: LoanAssistantRole.user,
      content: query,
      timestamp: DateTime.now(),
      state: LoanAssistantMessageState.complete,
      isFresh: true,
    );
    _messages.add(userMessage);
    _settleFresh(userMessage.id);

    final typingMessage = LoanAssistantMessage(
      id: _id('assistant'),
      role: LoanAssistantRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      state: LoanAssistantMessageState.typing,
      isFresh: true,
    );
    _messages.add(typingMessage);
    _expanded[typingMessage.id] = true;
    isSending = true;
    notifyListeners();

    try {
      final stream = _repository.replyStream(
        context: LoanAssistantConversationContext(
          report: report,
          targetClauseId: targetClauseId,
          history: List.unmodifiable(
            _messages.where((m) => m.state == LoanAssistantMessageState.complete),
          ),
        ),
        query: query,
      );

      String accumulatedAnswer = '';
      await for (final event in stream) {
        final index = _messages.indexWhere((m) => m.id == typingMessage.id);
        if (index == -1) break;

        if (event is LoanAssistantTokenEvent) {
          accumulatedAnswer += event.token;

          _messages[index] = LoanAssistantMessage(
            id: typingMessage.id,
            role: LoanAssistantRole.assistant,
            content: accumulatedAnswer,
            timestamp: typingMessage.timestamp,
            state: LoanAssistantMessageState.complete,
            isFresh: false,
            card: LoanAssistantCardData(
              engineLabel: 'LOANSENSE AI ENGINE (STREAMING)',
              answerLabel: 'AI Response',
              answer: accumulatedAnswer,
              simplifiedAnswer: accumulatedAnswer,
              sourceClause: '',
              pageReference: '',
              riskContext: '',
              highlightTerms: const [],
              insightChips: const [],
              references: const [],
            ),
          );
          notifyListeners();
        } else if (event is LoanAssistantFinalEvent) {
          final reply = event.reply;
          _messages[index] = reply.assistantMessage.copyWith(
            id: typingMessage.id,
            content: accumulatedAnswer.isNotEmpty
                ? accumulatedAnswer
                : reply.assistantMessage.content,
            timestamp: DateTime.now(),
            isFresh: true,
          );
          suggestions = reply.suggestions;
          contextLabel = reply.contextLabel;
          _expanded[typingMessage.id] = true;
          _settleFresh(typingMessage.id);
        }
      }
    } catch (e, stackTrace) {
      developer.log('Loan assistant reply failed: $e', stackTrace: stackTrace);
      final index = _messages.indexWhere((m) => m.id == typingMessage.id);
      if (index != -1) {
        _messages[index] = _buildFailureMessage(id: typingMessage.id, error: e);
        _expanded[typingMessage.id] = true;
        _settleFresh(typingMessage.id);
      }
      suggestions = const [
        LoanAssistantSuggestion(
          label: 'Retry question',
          prompt: 'Please answer my last question again.',
          accent: Color(0xFFC3C6D7),
        ),
        LoanAssistantSuggestion(
          label: 'Check charges',
          prompt: 'What charges and penalties apply in this loan?',
          accent: Color(0xFFDBC3A8),
        ),
      ];
      contextLabel = 'Assistant unavailable';
    } finally {
      isSending = false;
      notifyListeners();
    }
  }

  void toggleListening() {
    isListening = !isListening;
    notifyListeners();
  }

  void toggleAttachment() {
    hasAttachment = !hasAttachment;
    notifyListeners();
  }

  void toggleSimple(String id) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final message = _messages[index];
    if (message.card == null) return;
    _messages[index] = message.copyWith(showSimpleAnswer: !message.showSimpleAnswer);
    notifyListeners();
  }

  void toggleExpanded(String id) {
    _expanded[id] = !(_expanded[id] ?? true);
    notifyListeners();
  }

  bool isExpanded(String id) => _expanded[id] ?? true;

  LoanAssistantMessage _buildFailureMessage({
    required String id,
    required Object error,
  }) {
    final details = error.toString();
    final hint = details.contains('NVIDIA_API_KEY')
        ? 'The backend AI key is missing or invalid.'
        : details.contains('Connection timeout') || details.contains('network failure')
            ? 'The app could not reach the backend service.'
            : 'The assistant could not produce a response.';
    final answer = 'I could not get a response just now. $hint Please try again.';

    return LoanAssistantMessage(
      id: id,
      role: LoanAssistantRole.assistant,
      content: answer,
      timestamp: DateTime.now(),
      state: LoanAssistantMessageState.complete,
      isFresh: true,
      card: LoanAssistantCardData(
        engineLabel: 'LOANSENSE AI ENGINE',
        answerLabel: 'Connection status',
        answer: answer,
        simplifiedAnswer: answer,
        sourceClause: '',
        pageReference: '',
        riskContext: hint,
        highlightTerms: const [],
        insightChips: const [],
        references: [],
      ),
    );
  }

  void _settleFresh(String id) {
    Timer(const Duration(milliseconds: 20), () {
      final index = _messages.indexWhere((m) => m.id == id);
      if (index == -1) return;
      if (!_messages[index].isFresh) return;
      _messages[index] = _messages[index].copyWith(isFresh: false);
      notifyListeners();
    });
  }

  String _id(String prefix) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}';
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}
