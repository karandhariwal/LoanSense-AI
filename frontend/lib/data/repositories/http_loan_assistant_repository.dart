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
}
