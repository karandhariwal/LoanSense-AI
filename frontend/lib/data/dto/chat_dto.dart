import 'package:flutter/material.dart';
import 'package:loansense_ai/data/models/loan_assistant_models.dart';

class ChatResponseDto {
  final String answer;
  final List<CitationDto> citations;
  final double confidenceScore;
  final String? sessionId;

  ChatResponseDto({
    required this.answer,
    required this.citations,
    required this.confidenceScore,
    this.sessionId,
  });

  factory ChatResponseDto.fromJson(Map<String, dynamic> json) {
    return ChatResponseDto(
      answer: json['answer']?.toString() ?? '',
      citations: (json['citations'] as List?)
              ?.map((e) => CitationDto.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.0,
      sessionId: json['session_id']?.toString(),
    );
  }

  LoanAssistantReply toDomain(String query) {
    // 1. Determine target references and labels
    final hasCitations = citations.isNotEmpty;
    final primaryCitation = hasCitations ? citations.first : null;
    final sourceClause = primaryCitation?.clauseReference ?? 'General Provision';
    final pageNum = primaryCitation?.pageNumber ?? 1;
    final pageReference = 'Page $pageNum';

    // 2. Generate Insight Chips
    final insightChips = [
      LoanAssistantInsightChip(
        label: 'Confidence: ${(confidenceScore * 100).toStringAsFixed(0)}%',
        accent: const Color(0xFFC3C6D7),
        icon: Icons.check_circle_outline_rounded,
      ),
      if (hasCitations)
        LoanAssistantInsightChip(
          label: primaryCitation!.citationType,
          accent: const Color(0xFFDBC3A8),
          icon: Icons.gavel_rounded,
        ),
    ];

    // 3. Generate References list
    final references = citations.map((c) {
      return LoanAssistantReference(
        label: c.clauseReference,
        value: c.sourceText,
        accent: const Color(0xFFC3C6D7),
        icon: Icons.description_outlined,
      );
    }).toList();

    // 4. Extract terms for highlighting
    final terms = ['foreclosure', 'prepayment', 'penalty', 'charges', 'interest', 'rate', 'emi', 'unilateral', 'fees'];
    final highlights = terms.where((t) => answer.toLowerCase().contains(t)).toList();

    // 5. Build card data
    final card = LoanAssistantCardData(
      engineLabel: 'LOANSENSE AI ENGINE 4.2',
      answerLabel: 'AI RAG Insights',
      answer: answer,
      simplifiedAnswer: answer, // Same as answer for full transparency
      sourceClause: sourceClause,
      pageReference: pageReference,
      riskContext: 'Verified provision extracted under legal context extraction.',
      highlightTerms: highlights,
      insightChips: insightChips,
      references: references,
    );

    final assistantMessage = LoanAssistantMessage(
      id: 'assistant-${DateTime.now().millisecondsSinceEpoch}',
      role: LoanAssistantRole.assistant,
      content: answer,
      timestamp: DateTime.now(),
      state: LoanAssistantMessageState.complete,
      card: card,
      showSimpleAnswer: false,
      isFresh: true,
    );

    // Dynamic suggestions based on query
    final lower = query.toLowerCase();
    final suggestions = <LoanAssistantSuggestion>[];
    if (lower.contains('foreclosure') || lower.contains('prepay') || lower.contains('close')) {
      suggestions.addAll([
        const LoanAssistantSuggestion(label: 'What hidden charges apply?', prompt: 'Are there hidden fees or charges in early prepayment?', accent: Color(0xFFC3C6D7)),
        const LoanAssistantSuggestion(label: 'Can I waive charges?', prompt: 'How do I negotiate to waive foreclosure charges?', accent: Color(0xFFDBC3A8)),
      ]);
    } else {
      suggestions.addAll([
        const LoanAssistantSuggestion(label: 'Explain foreclosure terms', prompt: 'Tell me about the prepayment and foreclosure rules.', accent: Color(0xFFC3C6D7)),
        const LoanAssistantSuggestion(label: 'Show risk levels', prompt: 'Which clauses carry the highest risk level?', accent: Color(0xFFFFB4AB)),
      ]);
    }

    return LoanAssistantReply(
      assistantMessage: assistantMessage,
      suggestions: suggestions,
      contextLabel: sourceClause,
    );
  }
}

class CitationDto {
  final int pageNumber;
  final String sourceText;
  final double confidence;
  final String citationType;
  final String clauseReference;

  CitationDto({
    required this.pageNumber,
    required this.sourceText,
    required this.confidence,
    required this.citationType,
    required this.clauseReference,
  });

  factory CitationDto.fromJson(Map<String, dynamic> json) {
    return CitationDto(
      pageNumber: (json['page_number'] as num?)?.toInt() ?? 1,
      sourceText: json['source_text']?.toString() ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      citationType: json['citation_type']?.toString() ?? 'legal_provision',
      clauseReference: json['clause_reference']?.toString() ?? 'Clause Reference',
    );
  }
}
