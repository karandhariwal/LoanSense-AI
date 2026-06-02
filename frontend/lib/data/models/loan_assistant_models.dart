import 'package:flutter/material.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';

enum LoanAssistantRole { user, assistant, system }

enum LoanAssistantMessageState { typing, complete }

class LoanAssistantSuggestion {
  final String label;
  final String prompt;
  final Color accent;

  const LoanAssistantSuggestion({
    required this.label,
    required this.prompt,
    required this.accent,
  });
}

class LoanAssistantInsightChip {
  final String label;
  final Color accent;
  final IconData? icon;

  const LoanAssistantInsightChip({
    required this.label,
    required this.accent,
    this.icon,
  });
}

class LoanAssistantReference {
  final String label;
  final String value;
  final Color accent;
  final IconData icon;

  const LoanAssistantReference({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
  });
}

class LoanAssistantCardData {
  final String engineLabel;
  final String answerLabel;
  final String answer;
  final String simplifiedAnswer;
  final String sourceClause;
  final String pageReference;
  final String riskContext;
  final List<String> highlightTerms;
  final List<LoanAssistantInsightChip> insightChips;
  final List<LoanAssistantReference> references;

  const LoanAssistantCardData({
    required this.engineLabel,
    required this.answerLabel,
    required this.answer,
    required this.simplifiedAnswer,
    required this.sourceClause,
    required this.pageReference,
    required this.riskContext,
    required this.highlightTerms,
    required this.insightChips,
    required this.references,
  });
}

class LoanAssistantMessage {
  final String id;
  final LoanAssistantRole role;
  final String content;
  final DateTime timestamp;
  final LoanAssistantMessageState state;
  final LoanAssistantCardData? card;
  final bool showSimpleAnswer;
  final bool isFresh;

  const LoanAssistantMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    required this.state,
    this.card,
    this.showSimpleAnswer = false,
    this.isFresh = false,
  });

  LoanAssistantMessage copyWith({
    String? id,
    LoanAssistantRole? role,
    String? content,
    DateTime? timestamp,
    LoanAssistantMessageState? state,
    LoanAssistantCardData? card,
    bool? showSimpleAnswer,
    bool? isFresh,
  }) {
    return LoanAssistantMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      state: state ?? this.state,
      card: card ?? this.card,
      showSimpleAnswer: showSimpleAnswer ?? this.showSimpleAnswer,
      isFresh: isFresh ?? this.isFresh,
    );
  }
}

class LoanAssistantConversationSeed {
  final List<LoanAssistantMessage> messages;
  final List<LoanAssistantSuggestion> suggestions;
  final String documentLabel;
  final String pageLabel;
  final String contextLabel;

  const LoanAssistantConversationSeed({
    required this.messages,
    required this.suggestions,
    required this.documentLabel,
    required this.pageLabel,
    required this.contextLabel,
  });
}

class LoanAssistantReply {
  final LoanAssistantMessage assistantMessage;
  final List<LoanAssistantSuggestion> suggestions;
  final String contextLabel;

  const LoanAssistantReply({
    required this.assistantMessage,
    required this.suggestions,
    required this.contextLabel,
  });
}

class LoanAssistantConversationContext {
  final LoanAnalysisReport report;
  final String? targetClauseId;
  final List<LoanAssistantMessage> history;

  const LoanAssistantConversationContext({
    required this.report,
    required this.history,
    this.targetClauseId,
  });
}
