import 'package:flutter/material.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';
import 'package:loansense_ai/data/models/loan_assistant_models.dart';
import 'package:loansense_ai/data/repositories/loan_assistant_repository.dart';
import 'package:loansense_ai/data/repositories/loan_repository.dart';
import 'package:loansense_ai/data/dto/chat_dto.dart';

class HttpLoanAssistantRepository implements LoanAssistantRepository {
  final LoanRepository _loanRepository;

  HttpLoanAssistantRepository({LoanRepository? loanRepository})
      : _loanRepository = loanRepository ?? LoanRepository();

  @override
  LoanAssistantConversationSeed bootstrap(LoanAnalysisReport report) {
    // Synchronously generate initial greeting and suggestions
    final now = DateTime.now();
    return LoanAssistantConversationSeed(
      messages: [
        LoanAssistantMessage(
          id: 'welcome-${now.millisecondsSinceEpoch}',
          role: LoanAssistantRole.assistant,
          content:
              'Hi! I am your LoanSense AI Assistant. Ask me any question about your loan agreement with ${report.lenderName}. I can explain exit fees, interest resets, bounce charges, and risk clauses in plain English.',
          timestamp: now.subtract(const Duration(seconds: 1)),
          state: LoanAssistantMessageState.complete,
          isFresh: false,
        ),
      ],
      suggestions: const [
        LoanAssistantSuggestion(
          label: 'Can I close this loan early?',
          prompt: 'Can I close this loan early?',
          accent: Color(0xFFC3C6D7),
        ),
        LoanAssistantSuggestion(
          label: 'Are there exit penalties?',
          prompt: 'What exit penalties and foreclosure charges apply?',
          accent: Color(0xFFDBC3A8),
        ),
        LoanAssistantSuggestion(
          label: 'Late fee risks?',
          prompt: 'What are the penalties or late fees if I miss an EMI?',
          accent: Color(0xFFFFB4AB),
        ),
      ],
      documentLabel: '${report.lenderName}_Agreement.pdf',
      pageLabel: 'Page 1',
      contextLabel: report.healthSummary,
    );
  }

  @override
  Future<LoanAssistantReply> reply({
    required LoanAssistantConversationContext context,
    required String query,
  }) async {
    // Map domain messages history to api schema list of maps
    final historyMaps = context.history.map((m) {
      return {
        "role": m.role == LoanAssistantRole.user ? "user" : "assistant",
        "content": m.content,
      };
    }).toList();

    // Call real backend chat API
    final responseMap = await _loanRepository.chatWithLoan(
      context.report.loanId,
      query,
      history: historyMaps,
    );

    // Map response DTO to domain entities
    final dto = ChatResponseDto.fromJson(responseMap);
    return dto.toDomain(query);
  }

  @override
  Future<List<LoanAssistantMessage>> fetchHistory(String loanId) async {
    final rawHistory = await _loanRepository.fetchChatHistory(loanId);
    
    final List<LoanAssistantMessage> messages = [];
    int userMessageIndex = 1;
    int assistantMessageIndex = 1;

    for (final rawMsg in rawHistory) {
      final roleStr = rawMsg['role']?.toString() ?? 'user';
      final content = rawMsg['content']?.toString() ?? '';
      final timestampStr = rawMsg['created_at']?.toString();
      final timestamp = timestampStr != null 
          ? DateTime.tryParse(timestampStr) ?? DateTime.now()
          : DateTime.now();

      if (roleStr == 'user') {
        messages.add(
          LoanAssistantMessage(
            id: 'history-user-$loanId-${userMessageIndex++}-${timestamp.millisecondsSinceEpoch}',
            role: LoanAssistantRole.user,
            content: content,
            timestamp: timestamp,
            state: LoanAssistantMessageState.complete,
            isFresh: false,
          ),
        );
      } else {
        final citationsRaw = rawMsg['citations'] as List? ?? [];
        final confidence = (rawMsg['confidence_score'] as num?)?.toDouble() ?? 0.85;

        final dto = ChatResponseDto(
          answer: content,
          citations: citationsRaw
              .map((c) => CitationDto.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList(),
          confidenceScore: confidence,
          sessionId: 'history-$loanId',
        );

        final domainReply = dto.toDomain("What is this clause?");
        
        messages.add(
          domainReply.assistantMessage.copyWith(
            id: 'history-assistant-$loanId-${assistantMessageIndex++}-${timestamp.millisecondsSinceEpoch}',
            timestamp: timestamp,
            isFresh: false,
          ),
        );
      }
    }

    return messages;
  }

  @override
  Stream<LoanAssistantStreamEvent> replyStream({
    required LoanAssistantConversationContext context,
    required String query,
  }) async* {
    final historyMaps = context.history.map((m) {
      return {
        "role": m.role == LoanAssistantRole.user ? "user" : "assistant",
        "content": m.content,
      };
    }).toList();

    final stream = _loanRepository.chatWithLoanStream(
      context.report.loanId,
      query,
      history: historyMaps,
    );

    String accumulatedAnswer = '';
    await for (final event in stream) {
      final type = event['type'] as String?;
      if (type == 'token') {
        final content = event['content']?.toString() ?? '';
        accumulatedAnswer += content;
        yield LoanAssistantTokenEvent(content);
      } else if (type == 'final') {
        final citationsRaw = event['citations'] as List? ?? [];
        final confidence = (event['confidence_score'] as num?)?.toDouble() ?? 0.85;

        final dto = ChatResponseDto(
          answer: accumulatedAnswer,
          citations: citationsRaw
              .map((c) => CitationDto.fromJson(Map<String, dynamic>.from(c as Map)))
              .toList(),
          confidenceScore: confidence,
          sessionId: 'stream-${context.report.loanId}',
        );

        final domainReply = dto.toDomain(query);
        yield LoanAssistantFinalEvent(domainReply);
      }
    }
  }
}
