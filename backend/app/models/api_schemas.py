from datetime import datetime
from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field, ConfigDict
from .risk_clause import RiskClause
from .loan_analysis import LoanAnalysisResponse
from .loan_comparison import LoanComparison
from .chat_citation import RAGResponse


class AnalysisResponse(BaseModel):
    """
    Response model returned by GET /analysis/{loan_id}.
    Wraps the core analysis details along with transaction metadata.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "loan_id": "8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f",
                "status": "success",
                "analysis": {
                    "metadata": {
                        "lender_name": "Apex Finance Corp",
                        "loan_type": "Home Loan",
                        "principal_amount": "5000000.00",
                        "sanctioned_amount": "5000000.00",
                        "interest_rate": 8.75,
                        "interest_type": "floating",
                        "tenure_months": 240,
                        "emi_amount": "44186.00",
                    },
                    "risks": [],
                    "ai_summary": "Extracted details successfully.",
                    "loan_score": {
                        "score": 7.8,
                        "rating": "Good",
                        "strengths": [],
                        "weaknesses": [],
                        "explanation": "Transparent structure.",
                    },
                    "confidence_score": 0.94,
                    "total_interest": "5604640.00",
                    "total_payment": "10604640.00",
                    "effective_apr": 8.92,
                    "recommendations": [],
                },
            }
        }
    )

    loan_id: str = Field(
        ...,
        description="The unique identifier of the analyzed loan document.",
    )

    status: str = Field(
        "success",
        description="The processing status of the analysis (e.g. 'success', 'processing', 'failed').",
    )

    analysis: Optional[LoanAnalysisResponse] = Field(
        default=None,
        description="The actual AI loan analysis results.",
    )


class LoanHistoryItemResponse(BaseModel):
    """
    Response item returned by GET /loans.
    Contains the dashboard-facing summary for one analyzed upload.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "loan_id": "8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f",
                "lender_name": "Apex Finance Corp",
                "upload_date": "2026-06-07T13:25:14.000000Z",
                "status": "COMPLETED",
                "risk_score": 22.0,
            }
        }
    )

    loan_id: str = Field(
        ...,
        description="The unique identifier of the uploaded loan document.",
    )

    lender_name: str = Field(
        ...,
        description="Resolved lender name if available, otherwise a fallback label.",
    )

    upload_date: datetime = Field(
        ...,
        description="The UTC timestamp when the loan document was uploaded.",
    )

    status: str = Field(
        ...,
        description="The current processing status of the loan analysis.",
    )

    risk_score: Optional[float] = Field(
        default=None,
        ge=0.0,
        le=100.0,
        description="Derived risk percentage where higher means riskier. Null until analysis is available.",
    )


class RisksResponse(BaseModel):
    """
    Response model returned by GET /risks/{loan_id}.
    Aggregates risk clause findings and count statistics.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "loan_id": "8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f",
                "total_risks": 1,
                "high_risks_count": 1,
                "medium_risks_count": 0,
                "low_risks_count": 0,
                "risks": [
                    {
                        "clause_id": "clause_interest_rate_hike",
                        "clause_title": "Unilateral Floating Rate Adjustment",
                        "clause_text": "The Lender reserves the absolute right to modify the margin and/or the Benchmark Rate at any time...",
                        "risk_level": "HIGH",
                        "category": "Interest Rate Risk",
                        "explanation": "Allows the lender to increase interest rates unilaterally...",
                        "page_number": 12,
                        "recommendation": "Negotiate to require at least a 30-day prior written notice...",
                    }
                ],
            }
        }
    )

    loan_id: str = Field(
        ...,
        description="The unique identifier of the loan document.",
    )

    risks: List[RiskClause] = Field(
        default_factory=list,
        description="List of risk clauses extracted from the loan agreement.",
    )

    total_risks: int = Field(
        ...,
        ge=0,
        description="The total count of risk clauses detected.",
    )

    high_risks_count: int = Field(
        ...,
        ge=0,
        description="The count of detected high-severity risks.",
    )

    medium_risks_count: int = Field(
        ...,
        ge=0,
        description="The count of detected medium-severity risks.",
    )

    low_risks_count: int = Field(
        ...,
        ge=0,
        description="The count of detected low-severity risks.",
    )


class CompareRequest(BaseModel):
    """
    Request model for POST /compare.
    Accepts two pre-analyzed loan IDs to perform a comparison.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "loan_id_a": "8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f",
                "loan_id_b": "9f8e7d6c-5b4a-3c2d-1e0f-9a8b7c6d5e4f",
            }
        }
    )

    loan_id_a: str = Field(
        ...,
        description="The unique identifier of Loan A (which has already been processed).",
    )

    loan_id_b: str = Field(
        ...,
        description="The unique identifier of Loan B (which has already been processed).",
    )


class CompareResponse(BaseModel):
    """
    Response model returned by POST /compare.
    Contains the structured loan comparison.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "comparison": {
                    "loan_a": {
                        "lender_name": "Apex Finance Corp",
                        "loan_type": "Home Loan",
                        "principal_amount": "5000000.00",
                        "sanctioned_amount": "5000000.00",
                        "interest_rate": 8.75,
                        "interest_type": "floating",
                        "tenure_months": 240,
                        "emi_amount": "44186.00",
                    },
                    "loan_b": {
                        "lender_name": "Summit Credits",
                        "loan_type": "Home Loan",
                        "principal_amount": "5000000.00",
                        "sanctioned_amount": "5000000.00",
                        "interest_rate": 9.25,
                        "interest_type": "fixed",
                        "tenure_months": 240,
                        "emi_amount": "45820.00",
                    },
                    "comparison_results": {
                        "cost_difference": "-392160.00",
                        "interest_difference": "-392160.00",
                        "risk_difference": "Loan A is floating rate, while Loan B is a fixed rate...",
                        "recommended_loan": "Loan A",
                        "recommendation_reason": "Loan A is cheaper by $392,160...",
                    },
                }
            }
        }
    )

    comparison: LoanComparison = Field(
        ...,
        description="The detailed cost, interest, and risk comparison values.",
    )


class ChatRequest(BaseModel):
    """
    Request model for POST /chat.
    Conveys the query and optional chat parameters.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "query": "Is there any prepayment charge in my loan agreement?",
                "history": [
                    {"role": "user", "content": "Hi, who are you?"},
                    {"role": "assistant", "content": "I am LoanSense AI, your assistant."},
                ],
            }
        }
    )

    query: str = Field(
        ...,
        description="The question or search query concerning the loan agreement.",
        min_length=3,
    )

    history: Optional[List[Dict[str, Any]]] = Field(
        default_factory=list,
        description="List of past conversational dialogue logs for context retrieval.",
    )


class ChatResponse(RAGResponse):
    """
    Response model returned by POST /chat.
    Extends RAGResponse to include specific session telemetry.
    """

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "answer": "Yes, you can prepay the loan, but according to Page 8, Clause 7.2, it is subject to a prepayment charge of 2% of the prepaid principal amount.",
                "citations": [
                    {
                        "page_number": 8,
                        "source_text": "7.2 Prepayment: The Borrower may prepay the outstanding loan amount in whole or part subject to a prepayment fee of 2.0% of the prepaid principal.",
                        "confidence": 0.98,
                        "citation_type": "legal_provision",
                        "clause_reference": "Clause 7.2",
                    }
                ],
                "confidence_score": 0.95,
                "session_id": "chat_session_9a8b7c6d",
            }
        }
    )

    session_id: Optional[str] = Field(
        None,
        description="Unique identifier for the chat conversation session.",
    )
