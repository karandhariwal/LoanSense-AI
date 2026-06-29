import 'dart:async';
import 'dart:math';
import 'dart:ui';
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
  late final AnimationController _ambientController;
  late final AnimationController _heroController;
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
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.removeListener(_queueScroll);
    _controller.dispose();
    _scrollController.dispose();
    _ambientController.dispose();
    _heroController.dispose();
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
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    const bottomGutter = 156.0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: _AiPalette.background,
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.012),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: _Backdrop()),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _ambientController,
                    builder: (_, __) => CustomPaint(
                      painter: _NoisePainter(seed: 100, opacity: 0.045),
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([_controller, _ambientController]),
                      builder: (_, __) {
                        final docContext = _controller.isLoading
                            ? 'Connecting to Intelligence Core...'
                            : (_controller.documentLabel.trim().isEmpty
                                ? _controller.contextLabel
                                : '${_controller.documentLabel} • ${_controller.pageLabel}');
                        return _TopBar(
                          glow: _ambientController.value,
                          contextLabel: docContext,
                          onBack: () {
                            HapticFeedback.selectionClick();
                            final navigator = Navigator.of(context);
                            if (navigator.canPop()) {
                              navigator.maybePop();
                              return;
                            }
                            navigator.pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (_) => const HomeDashboardScreen(),
                              ),
                              (route) => false,
                            );
                          },
                        );
                      },
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _controller,
                          _ambientController,
                          _heroController,
                        ]),
                        builder: (_, __) {
                          if (_controller.isLoading) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFC3C6D7),
                              ),
                            );
                          }
                          return ListView(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              20,
                              18,
                              20,
                              bottomGutter + keyboardInset,
                            ),
                            children: [
                              _Hero(glow: _heroController.value),
                              const SizedBox(height: 28),
                              ..._controller.messages.map(
                                (message) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _AnimatedEntry(
                                    fresh: message.isFresh,
                                    child: message.role == LoanAssistantRole.user
                                        ? _UserBubble(message: message)
                                        : _AssistantBubble(
                                            message: message,
                                            expanded:
                                                _controller.isExpanded(message.id),
                                            onCopy: () => _copy(message),
                                            onShare: () => _share(message),
                                            onToggleSimple: () =>
                                                _controller.toggleSimple(message.id),
                                            onToggleExpanded: () => _controller
                                                .toggleExpanded(message.id),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              _SuggestedQueries(
                                suggestions: _controller.suggestions,
                                onTap: _send,
                              ),
                              const SizedBox(height: 32),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.only(bottom: keyboardInset),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _InputDock(
                          controller: _inputController,
                          focusNode: _inputFocus,
                          onSend: _controller.isLoading ? (_) {} : _send,
                          listening: _controller.isListening,
                          onMicTap: _controller.isLoading ? () {} : _controller.toggleListening,
                          onAttachTap: _controller.isLoading ? () {} : _controller.toggleAttachment,
                        ),
                      ],
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

  Future<void> _send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _controller.isSending) return;
    FocusScope.of(context).unfocus();
    _inputController.clear();
    await _controller.sendMessage(text);
  }

  Future<void> _copy(LoanAssistantMessage message) async {
    final card = message.card;
    if (card == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: [
          card.answer,
          card.sourceClause,
          card.pageReference,
          card.riskContext,
        ].join('\n\n'),
      ),
    );
    _toast('Response copied to clipboard');
  }

  Future<void> _share(LoanAssistantMessage message) async {
    final card = message.card;
    if (card == null) return;
    await Clipboard.setData(
      ClipboardData(
        text: [
          'LoanSense AI',
          card.answer,
          card.pageReference,
          card.sourceClause,
        ].join('\n\n'),
      ),
    );
    _toast('Share text copied to clipboard');
  }

  void _toast(String text) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _AiPalette.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Text(
                text,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _AiPalette.primaryText,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

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
  }) : _report = report,
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

    // Guard: never attempt a network call with an empty/invalid loan ID.
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
              sourceClause: 'Analyzing document context...',
              pageReference: 'Retrieving citations...',
              riskContext: 'Verifying legal provisions in real-time.',
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
            content: accumulatedAnswer.isNotEmpty ? accumulatedAnswer : reply.assistantMessage.content,
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
      developer.log(
        'Loan assistant reply failed: $e',
        stackTrace: stackTrace,
      );
      final index = _messages.indexWhere((m) => m.id == typingMessage.id);
      if (index != -1) {
        _messages[index] = _buildFailureMessage(
          id: typingMessage.id,
          error: e,
        );
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
        : details.contains('Connection timeout') ||
                  details.contains('network failure')
            ? 'The app could not reach the backend service.'
            : 'The assistant could not produce a response.';
    final answer =
        'I could not get a model response just now. $hint Please try again.';

    return LoanAssistantMessage(
      id: id,
      role: LoanAssistantRole.assistant,
      content: answer,
      timestamp: DateTime.now(),
      state: LoanAssistantMessageState.complete,
      isFresh: true,
      card: LoanAssistantCardData(
        engineLabel: 'LOANSENSE AI ENGINE 4.2',
        answerLabel: 'Connection status',
        answer: answer,
        simplifiedAnswer: answer,
        sourceClause: 'System status',
        pageReference: 'Assistant connection',
        riskContext: hint,
        highlightTerms: const ['response', 'backend', 'assistant'],
        insightChips: const [
          LoanAssistantInsightChip(
            label: 'Retry Required',
            accent: Color(0xFFFFB4AB),
            icon: Icons.refresh_rounded,
          ),
        ],
        references: [
          LoanAssistantReference(
            label: 'Technical detail',
            value: details,
            accent: const Color(0xFFFFB4AB),
            icon: Icons.error_outline_rounded,
          ),
        ],
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

class _AnimatedEntry extends StatelessWidget {
  final bool fresh;
  final Widget child;

  const _AnimatedEntry({required this.fresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: fresh ? 0 : 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: fresh ? const Offset(0, 0.05) : Offset.zero,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final double glow;
  final VoidCallback onBack;
  final String contextLabel;

  const _TopBar({
    required this.glow,
    required this.onBack,
    required this.contextLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _AiPalette.background.withValues(alpha: 0.96),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TopBackButton(glow: glow, onTap: onBack),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Assistant',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _AiPalette.primaryText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (contextLabel.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(9999),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: 13,
                                  color: _AiPalette.primaryText.withValues(alpha: 0.74),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    contextLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: _AiPalette.primaryText.withValues(alpha: 0.72),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _HeaderAvatar(glow: glow),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBackButton extends StatelessWidget {
  final double glow;
  final VoidCallback onTap;

  const _TopBackButton({
    required this.glow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: _AiPalette.primaryText.withValues(alpha: 0.16 + glow * 0.08),
                  blurRadius: 18,
                  spreadRadius: 0.2,
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: _AiPalette.primaryText.withValues(alpha: 0.92),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final double glow;

  const _Hero({required this.glow});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 182,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(182, 182),
                painter: _OrbPainter(glow: glow),
              ),
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _AiPalette.primaryText.withValues(alpha: 0.18),
                      const Color(0xFF10121B),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _AiPalette.primaryText.withValues(alpha: 0.16),
                      blurRadius: 36,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: _AiPalette.primaryText.withValues(alpha: 0.92),
                  size: 46,
                ),
              ),
            ],
          ),
        ),
        Text(
          'INTELLIGENCE CONSOLE ACTIVE',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _AiPalette.primaryText.withValues(alpha: 0.72),
            letterSpacing: 2.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Personalized Loan\nAnalysis',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: _AiPalette.primaryText,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  final LoanAssistantMessage message;

  const _UserBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 272),
        child: Container(
          decoration: BoxDecoration(
            color: _AiPalette.surface.withValues(alpha: 0.6),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 1.7,
                  decoration: const BoxDecoration(
                    color: _AiPalette.primaryText,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.content,
                      style: GoogleFonts.inter(
                        fontSize: 17,
                        height: 1.35,
                        color: _AiPalette.primaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _formatTime(message.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: _AiPalette.primaryText.withValues(alpha: 0.46),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final LoanAssistantMessage message;
  final bool expanded;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onToggleSimple;
  final VoidCallback onToggleExpanded;

  const _AssistantBubble({
    required this.message,
    required this.expanded,
    required this.onCopy,
    required this.onShare,
    required this.onToggleSimple,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    if (message.state == LoanAssistantMessageState.typing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _AiPalette.surface.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: const _TypingIndicator(),
      );
    }

    final card = message.card;
    if (card == null) return const SizedBox.shrink();
    final answer = message.showSimpleAnswer ? card.simplifiedAnswer : card.answer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _AiPalette.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal_rounded, color: _AiPalette.primaryText, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  card.engineLabel,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _AiPalette.primaryText,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _ActionDot(icon: Icons.content_copy_rounded, onTap: onCopy),
              const SizedBox(width: 8),
              _ActionDot(icon: Icons.ios_share_rounded, onTap: onShare),
              const SizedBox(width: 8),
              _ActionDot(
                icon: message.showSimpleAnswer
                    ? Icons.verified_outlined
                    : Icons.auto_fix_high_rounded,
                onTap: onToggleSimple,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            card.answerLabel.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _AiPalette.primaryText.withValues(alpha: 0.7),
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          _HighlightedAnswer(text: answer, highlightTerms: card.highlightTerms),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: expanded
                ? Column(
                    children: [
                      _InfoCard(
                        title: 'Source Clause',
                        body: card.sourceClause,
                        icon: Icons.description_outlined,
                        accent: const Color(0xFFC3C6D7),
                        italic: true,
                      ),
                      const SizedBox(height: 10),
                      _InfoCard(
                        title: 'Page Reference',
                        body: card.pageReference,
                        icon: Icons.article_outlined,
                        accent: const Color(0xFFC3C6D7),
                      ),
                      const SizedBox(height: 10),
                      _RiskCard(body: card.riskContext),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: card.insightChips
                            .map((chip) => _InsightPill(chip: chip))
                            .toList(),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _GhostButton(
                label: 'Explain Simpler',
                icon: Icons.auto_awesome_rounded,
                onTap: onToggleSimple,
              ),
              _GhostButton(
                label: expanded ? 'Collapse' : 'Expand',
                icon: expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                onTap: onToggleExpanded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _formatTime(message.timestamp),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _AiPalette.primaryText.withValues(alpha: 0.46),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal_rounded, color: _AiPalette.primaryText, size: 18),
                const SizedBox(width: 10),
                Text(
                  'PROCESSING ENGINE 2.4B',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _AiPalette.primaryText,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(3, (index) {
                final phase = ((_controller.value * 3) - index).clamp(0.0, 1.0);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Opacity(
                    opacity: (Curves.easeInOut
                            .transform(1 - (phase - 0.5).abs() * 2)
                            .clamp(0.2, 1.0))
                        .toDouble(),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _AiPalette.primaryText,
                        boxShadow: [
                          BoxShadow(
                            color: _AiPalette.primaryText.withValues(alpha: 0.22),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _HighlightedAnswer extends StatelessWidget {
  final String text;
  final List<String> highlightTerms;

  const _HighlightedAnswer({
    required this.text,
    required this.highlightTerms,
  });

  @override
  Widget build(BuildContext context) {
    if (highlightTerms.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 17,
          height: 1.55,
          color: _AiPalette.primaryText,
        ),
      );
    }

    final lower = text.toLowerCase();
    final spans = <TextSpan>[];
    var index = 0;

    while (index < text.length) {
      int? nextIndex;
      String? match;
      for (final term in highlightTerms) {
        final found = lower.indexOf(term.toLowerCase(), index);
        if (found == -1) continue;
        if (nextIndex == null || found < nextIndex) {
          nextIndex = found;
          match = term;
        }
      }

      if (nextIndex == null || match == null) {
        spans.add(TextSpan(text: text.substring(index)));
        break;
      }

      if (nextIndex > index) {
        spans.add(TextSpan(text: text.substring(index, nextIndex)));
      }
      spans.add(
        TextSpan(
          text: text.substring(nextIndex, nextIndex + match.length),
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _AiPalette.primaryText,
          ),
        ),
      );
      index = nextIndex + match.length;
    }

    return RichText(
      text: TextSpan(
        style: GoogleFonts.inter(
          fontSize: 17,
          height: 1.55,
          color: _AiPalette.primaryText,
        ),
        children: spans,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  final bool italic;

  const _InfoCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 15),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _AiPalette.primaryText.withValues(alpha: 0.62),
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              color: _AiPalette.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final String body;

  const _RiskCard({required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF211C1A).withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 3,
              decoration: const BoxDecoration(
                color: _AiPalette.warning,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: _AiPalette.warning, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      'RISK CONTEXT',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _AiPalette.warning,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    height: 1.5,
                    color: _AiPalette.primaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightPill extends StatelessWidget {
  final LoanAssistantInsightChip chip;

  const _InsightPill({required this.chip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: chip.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: chip.accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chip.icon != null) ...[
            Icon(chip.icon, size: 13, color: chip.accent),
            const SizedBox(width: 6),
          ] else ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: chip.accent,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            chip.label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: chip.accent,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _AiPalette.primaryText.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _AiPalette.primaryText.withValues(alpha: 0.84),
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestedQueries extends StatelessWidget {
  final List<LoanAssistantSuggestion> suggestions;
  final ValueChanged<String> onTap;

  const _SuggestedQueries({
    required this.suggestions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recommended Queries',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: _AiPalette.primaryText.withValues(alpha: 0.72),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: suggestions
                .map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _QueryChip(label: item.label, onTap: () => onTap(item.prompt)),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _QueryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QueryChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: _AiPalette.surface.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _AiPalette.primaryText.withValues(alpha: 0.95),
          ),
        ),
      ),
    );
  }
}

class _InputDock extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSend;
  final bool listening;
  final VoidCallback onMicTap;
  final VoidCallback onAttachTap;

  const _InputDock({
    required this.controller,
    required this.focusNode,
    required this.onSend,
    required this.listening,
    required this.onMicTap,
    required this.onAttachTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _AiPalette.surface.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.45),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _DockIcon(
                      icon: Icons.attach_file_rounded,
                      active: true,
                      onTap: onAttachTap,
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        textInputAction: TextInputAction.send,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: _AiPalette.primaryText,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Inquire about your loan terms...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 16,
                            color: _AiPalette.primaryText.withValues(alpha: 0.34),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: onSend,
                      ),
                    ),
                    _DockIcon(
                      icon: listening ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                      active: listening,
                      onTap: onMicTap,
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => onSend(controller.text),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _AiPalette.primaryText,
                          boxShadow: [
                            BoxShadow(
                              color: _AiPalette.primaryText.withValues(alpha: 0.36),
                              blurRadius: 18,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: _AiPalette.background,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _DockIcon({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: active ? 0.12 : 0.04),
        ),
        child: Icon(
          icon,
          size: 18,
          color: active
              ? _AiPalette.primaryText
              : _AiPalette.primaryText.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}

class _ActionDot extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionDot({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.04),
        ),
        child: Icon(icon, size: 14, color: _AiPalette.primaryText.withValues(alpha: 0.8)),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final double glow;

  const _HeaderAvatar({required this.glow});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        gradient: const RadialGradient(
          colors: [
            Color(0xFF1B2A33),
            Color(0xFF090B10),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _AiPalette.primaryText.withValues(alpha: 0.22 + glow * 0.08),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'LS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _AiPalette.primaryText,
          ),
        ),
      ),
    );
  }
}

class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _AiPalette.background),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.8, -0.9),
                radius: 1.2,
                colors: [
                  const Color(0xFF1A1B2E).withValues(alpha: 0.55),
                  _AiPalette.background,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.9, 1.1),
                radius: 1.2,
                colors: [
                  const Color(0xFF0A1320).withValues(alpha: 0.75),
                  _AiPalette.background,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoisePainter extends CustomPainter {
  final int seed;
  final double opacity;

  _NoisePainter({required this.seed, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = Random(seed);
    for (var i = 0; i < 220; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final s = random.nextDouble() * 1.1;
      paint.color = Colors.white.withValues(alpha: random.nextDouble() * opacity);
      canvas.drawRect(Rect.fromLTWH(x, y, s, s), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}

class _OrbPainter extends CustomPainter {
  final double glow;

  _OrbPainter({required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: size.width, height: size.height);

    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFC3C6D7).withValues(alpha: 0.36),
          const Color(0xFF6A728A).withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, size.width * 0.42, orbPaint);

    final streakPaint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 18; i++) {
      final factor = i / 18;
      final xOffset = lerpDouble(-44, 44, factor)!;
      final yOffset = lerpDouble(-26, 26, (sin(glow * pi * 2 + factor * 8) + 1) / 2)!;
      final start = Offset(center.dx - 48 + xOffset, center.dy - 18 + yOffset);
      final end = Offset(start.dx + 54, start.dy - 24);
      streakPaint.color = Color.lerp(
            const Color(0xFF00E5FF).withValues(alpha: 0.18),
            const Color(0xFFDBC3A8).withValues(alpha: 0.12),
            factor,
          ) ??
          const Color(0xFFC3C6D7).withValues(alpha: 0.1);
      canvas.drawLine(start, end, streakPaint);
    }

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFC3C6D7).withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawCircle(center, size.width * 0.38, haloPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) => oldDelegate.glow != glow;
}

class _AiPalette {
  static const background = Color(0xFF131314);
  static const surface = Color(0xFF201F20);
  static const primaryText = Color(0xFFC3C6D7);
  static const warning = Color(0xFFDBC3A8);
}

String _formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}
