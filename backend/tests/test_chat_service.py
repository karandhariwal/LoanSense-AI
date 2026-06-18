import unittest
from unittest.mock import AsyncMock, MagicMock

from app.models.chat_citation import CitationType
from app.services.ai.chat_service import (
    ChatAnswerSchema,
    ChatCitationDraft,
    ChatService,
)


class _MockDocument:
    def __init__(self, page_content, metadata):
        self.page_content = page_content
        self.metadata = metadata


class TestChatService(unittest.IsolatedAsyncioTestCase):
    async def test_get_answer_normalizes_missing_citation_fields(self):
        service = ChatService()
        service._ensure_runtime = MagicMock()
        service._get_relevant_documents = AsyncMock(
            return_value=[
                _MockDocument(
                    "Clause 7.2 Prepayment is allowed after 12 EMIs with a 2% fee.",
                    {"source": "Agreement.pdf", "page_number": 8},
                )
            ]
        )
        service._invoke_structured_chain = AsyncMock(
            return_value=ChatAnswerSchema(
                answer="Prepayment is allowed after 12 EMIs and carries a 2% fee.",
                citations=[
                    ChatCitationDraft(
                        page_number=8,
                        source_text="Clause 7.2 Prepayment is allowed after 12 EMIs with a 2% fee.",
                        clause_reference="Clause 7.2",
                    )
                ],
                confidence_score=0.91,
            )
        )

        response = await service.get_answer("loan-123", "Can I prepay early?")

        self.assertEqual(response.answer, "Prepayment is allowed after 12 EMIs and carries a 2% fee.")
        self.assertEqual(len(response.citations), 1)
        self.assertEqual(response.citations[0].citation_type, CitationType.GENERAL)
        self.assertEqual(response.citations[0].confidence, 0.91)
        self.assertEqual(response.supporting_clauses, ["Clause 7.2"])

    async def test_get_answer_returns_unavailable_message_when_runtime_setup_fails(self):
        service = ChatService()
        service._ensure_runtime = MagicMock(side_effect=RuntimeError("NVIDIA_API_KEY missing"))

        response = await service.get_answer("loan-123", "Can I prepay early?")

        self.assertIn("temporarily unavailable", response.answer.lower())
        self.assertEqual(response.confidence_score, 0.0)
        self.assertEqual(response.citations, [])

    async def test_get_answer_returns_retry_message_when_structured_chain_fails(self):
        service = ChatService()
        service._ensure_runtime = MagicMock()
        service._get_relevant_documents = AsyncMock(
            return_value=[
                _MockDocument(
                    "Clause 4.1 contains the relevant foreclosure condition.",
                    {"source": "Agreement.pdf", "page_number": 4},
                )
            ]
        )
        service._invoke_structured_chain = AsyncMock(side_effect=ValueError("bad structured output"))

        response = await service.get_answer("loan-123", "Can I close the loan early?")

        self.assertIn("reliable answer", response.answer.lower())
        self.assertEqual(response.source_references, ["Agreement.pdf"])
        self.assertEqual(response.confidence_score, 0.0)


if __name__ == "__main__":
    unittest.main()
