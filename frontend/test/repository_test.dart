import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:loansense_ai/core/error/exceptions.dart';
import 'package:loansense_ai/core/network/api_client.dart';
import 'package:loansense_ai/data/repositories/loan_repository.dart';
import 'package:loansense_ai/data/repositories/http_loan_assistant_repository.dart';
import 'package:loansense_ai/data/models/loan_assistant_models.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';
import 'package:loansense_ai/data/models/loan_comparison_report.dart';
import 'package:loansense_ai/data/models/loan_history_item.dart';

// --- Mocks ---
class MockApiClient extends Mock implements ApiClient {}

class MockLoanRepository extends Mock implements LoanRepository {}

void main() {
  late MockApiClient mockApiClient;
  late LoanRepository loanRepository;
  late HttpLoanAssistantRepository assistantRepository;

  setUpAll(() {
    registerFallbackValue(Options());
  });

  setUp(() {
    mockApiClient = MockApiClient();
    loanRepository = LoanRepository(apiClient: mockApiClient);
    assistantRepository =
        HttpLoanAssistantRepository(loanRepository: loanRepository);
  });

  group('LoanRepository - fetchAnalysis', () {
    const loanId = 'test-loan-123';

    final mockAnalysisJson = {
      'loan_id': loanId,
      'status': 'completed',
      'analysis': {
        'metadata': {
          'lender_name': 'Apex Finance Corp',
          'loan_type': 'Home Loan',
          'principal_amount': '5000000.00',
          'interest_type': 'floating',
          'interest_rate': 8.75,
          'emi_amount': '44186.00',
          'processing_fee': '10000.00',
          'documentation_fee': '2500.00',
          'insurance_fee': '15000.00',
          'foreclosure_charges': '2.0',
          'prepayment_charges': '1.5',
          'bounce_charges': '500.00',
          'late_payment_fee': '24.00',
          'disbursal_amount': '4972500.00',
          'repayment_frequency': 'monthly',
          'loan_start_date': '2026-06-01',
          'maturity_date': '2046-06-01'
        },
        'risks': [
          {
            'clause_id': 'clause_1',
            'clause_title': 'Unilateral Floating Rate',
            'clause_text':
                'Lender can adjust benchmark interest rates at will...',
            'risk_level': 'HIGH',
            'category': 'Interest Rate Risk',
            'explanation':
                'Unilateral adjustments expose customer to rate shifts.',
            'page_number': 12,
            'recommendation': 'Request notification before any adjustments.'
          }
        ],
        'ai_summary': 'This is a standard home loan agreement with exit fees.',
        'loan_score': {
          'score': 7.8,
          'rating': 'Good',
          'strengths': ['Exit waiver after 12m'],
          'weaknesses': ['Unilateral floating reset'],
          'explanation': 'Transparent but watch for variable resetting.'
        },
        'confidence_score': 0.94,
        'total_interest': '5604640.00',
        'total_payment': '10604640.00',
        'effective_apr': 8.92,
        'recommendations': ['Negotiate rate reset buffer']
      }
    };

    test('should return LoanAnalysisReport when API returns success (200)',
        () async {
      // Arrange
      when(() => mockApiClient.get<Map<String, dynamic>>('/analysis/$loanId'))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: '/analysis/$loanId'),
                data: mockAnalysisJson,
                statusCode: 200,
              ));

      // Act
      final result = await loanRepository.fetchAnalysis(loanId);

      // Assert
      expect(result.loanId, loanId);
      expect(result.lenderName, 'Apex Finance Corp');
      expect(result.healthScore, 7.8);
      expect(result.alerts.length, 1);
      expect(result.alerts.first.id, 'clause_1');
      expect(result.alerts.first.severity, 'HIGH');
      verify(() => mockApiClient.get<Map<String, dynamic>>('/analysis/$loanId'))
          .called(1);
    });

    test('should rethrow ApiException when API client throws it', () async {
      // Arrange
      when(() => mockApiClient.get<Map<String, dynamic>>('/analysis/$loanId'))
          .thenThrow(const ApiException(
              message: 'Resource not found', statusCode: 404));

      // Act & Assert
      expect(
        () => loanRepository.fetchAnalysis(loanId),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('LoanRepository - fetchLoanHistory', () {
    final mockHistoryJson = [
      {
        'loan_id': 'loan-1',
        'lender_name': 'Apex Finance Corp',
        'upload_date': '2026-06-07T13:25:14Z',
        'status': 'COMPLETED',
        'risk_score': 22.0,
      },
      {
        'loan_id': 'loan-2',
        'lender_name': 'Pending lender detection',
        'upload_date': '2026-06-06T08:10:00Z',
        'status': 'PENDING',
        'risk_score': null,
      },
    ];

    test('should return parsed loan history items when endpoint succeeds',
        () async {
      when(() => mockApiClient.get<List<dynamic>>(
            '/loans',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => Response(
          requestOptions: RequestOptions(path: '/loans'),
          data: mockHistoryJson,
          statusCode: 200,
        ),
      );

      final result = await loanRepository.fetchLoanHistory();

      expect(result, hasLength(2));
      expect(result.first, isA<LoanHistoryItem>());
      expect(result.first.loanId, 'loan-1');
      expect(result.first.lenderName, 'Apex Finance Corp');
      expect(result.first.riskScore, 22.0);
      expect(result.last.status, 'PENDING');
      expect(result.last.riskScore, isNull);
      verify(() => mockApiClient.get<List<dynamic>>(
            '/loans',
            queryParameters: any(named: 'queryParameters'),
          )).called(1);
    });
  });

  group('LoanRepository - compareLoans', () {
    const loanIdA = 'loan-a-123';
    const loanIdB = 'loan-b-456';

    final mockCompareJson = {
      'comparison': {
        'loan_a': {
          'lender_name': 'Apex Bank',
          'loan_type': 'Home Loan',
          'principal_amount': '5000000.00',
          'interest_type': 'floating',
          'interest_rate': 8.5,
          'emi_amount': '43500.00',
          'processing_fee': '5000.00',
          'foreclosure_charges': '2.0',
        },
        'loan_b': {
          'lender_name': 'Summit Finance',
          'loan_type': 'Home Loan',
          'principal_amount': '5000000.00',
          'interest_type': 'fixed',
          'interest_rate': 9.0,
          'emi_amount': '45000.00',
          'processing_fee': '7500.00',
          'foreclosure_charges': '0.0',
        },
        'comparison_results': {
          'cost_difference': '-250000.00',
          'interest_difference': '-240000.00',
          'risk_difference': 'Loan A is cheaper but has floating reset risk.',
          'recommended_loan': 'Loan A',
          'recommendation_reason': 'Loan A offers cumulative savings of ₹250k.'
        }
      }
    };

    test(
        'should return LoanComparisonReport when comparison endpoint is requested',
        () async {
      // Arrange
      when(() => mockApiClient.post<Map<String, dynamic>>(
            '/compare',
            data: {
              'loan_id_a': loanIdA,
              'loan_id_b': loanIdB,
            },
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/compare'),
            data: mockCompareJson,
            statusCode: 200,
          ));

      // Act
      final result = await loanRepository.compareLoans(loanIdA, loanIdB);

      // Assert
      expect(result.loanA.lenderLabel, 'Apex Bank');
      expect(result.loanB.lenderLabel, 'Summit Finance');
      expect(result.recommendation.headline, 'Loan A is financially safer...');
      expect(result.recommendation.recommended, LoanSide.loanA);
      verify(() => mockApiClient.post<Map<String, dynamic>>(
            '/compare',
            data: {
              'loan_id_a': loanIdA,
              'loan_id_b': loanIdB,
            },
          )).called(1);
    });
  });

  group('HttpLoanAssistantRepository - reply', () {
    const loanId = 'loan-assistant-123';

    final mockChatJson = {
      'answer':
          'Prepayment is permitted after 12 months with a 2% foreclosure penalty.',
      'confidence_score': 0.96,
      'session_id': 'sess-123',
      'citations': [
        {
          'page_number': 4,
          'source_text':
              'Borrower may prepay the loan amount subject to a 2% fee.',
          'confidence': 0.98,
          'citation_type': 'Exit provision',
          'clause_reference': 'Clause 6.2'
        }
      ]
    };

    test(
        'should map and wrap backend chat response into assistant domain entities',
        () async {
      // Arrange
      const mockReport = LoanAnalysisReport(
        loanId: loanId,
        lenderName: 'Test Lender',
        productName: 'Test Product',
        healthScore: 8.5,
        healthSummary: 'Good health',
        detailedSummary: 'Detailed summary',
        simpleSummary: 'Simple summary',
        recommendedAction: 'Proceed',
        contractClarity: 'High',
        metrics: [],
        alerts: [],
        sources: [],
        costSlices: [],
        emiSeries: [],
        clauseChips: [],
        extractions: [],
      );

      final mockHistory = [
        LoanAssistantMessage(
          id: 'user-1',
          role: LoanAssistantRole.user,
          content: 'Hello',
          timestamp: DateTime.now(),
          state: LoanAssistantMessageState.complete,
        ),
      ];

      when(() => mockApiClient.post<Map<String, dynamic>>(
            '/chat/$loanId',
            data: {
              'query': 'What is prepayment rule?',
              'history': [
                {'role': 'user', 'content': 'Hello'},
              ],
            },
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: '/chat/$loanId'),
            data: mockChatJson,
            statusCode: 200,
          ));

      // Act
      final result = await assistantRepository.reply(
        context: LoanAssistantConversationContext(
          report: mockReport,
          history: mockHistory,
        ),
        query: 'What is prepayment rule?',
      );

      // Assert
      expect(
          result.assistantMessage.content, contains('Prepayment is permitted'));
      expect(result.assistantMessage.card?.sourceClause, 'Clause 6.2');
      expect(result.assistantMessage.card?.pageReference, 'Page 4');
      expect(result.assistantMessage.card?.references.length, 1);
      expect(result.assistantMessage.card?.references.first.value,
          contains('prepay the loan'));
    });
  });
}
