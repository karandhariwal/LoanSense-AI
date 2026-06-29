"""
tests/test_user_profile_api.py
Unit tests for the user profile, settings, document management, and auth endpoints.

Pattern follows the existing test_api.py convention:
  - unittest.TestCase + FastAPI TestClient
  - MagicMock for database session
  - Dependency overrides for service and DB
"""

import unittest
from unittest.mock import MagicMock, patch
from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.main import app
from app.database.session import get_db
from app.api.user import get_user_profile_service
from app.api.auth import get_user_profile_service as get_auth_service
from app.database.user_models import UserProfile, UserSettings
from app.models.user_profile_schemas import (
    DeleteDocumentsResponse,
    LogoutResponse,
    NotificationSettingsSchema,
    PrivacySettingsSchema,
    UserProfileResponse,
    UserSettingsResponse,
)
from app.services.user_profile_service import UserProfileService


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_NOW = datetime(2026, 6, 7, 12, 0, 0, tzinfo=timezone.utc)


def _make_profile(
    user_id: str = "default",
    display_name: str = "Test User",
    email: str = "test@loansense.ai",
    phone_number: str = "+91 99999 00000",
    avatar_url: str = None,
) -> UserProfile:
    p = UserProfile()
    p.id = 1
    p.user_id = user_id
    p.display_name = display_name
    p.email = email
    p.phone_number = phone_number
    p.avatar_url = avatar_url
    p.created_at = _NOW
    p.updated_at = _NOW
    return p


def _make_settings(user_id: str = "default") -> UserSettings:
    s = UserSettings()
    s.id = 1
    s.user_id = user_id
    s.theme_mode = "dark"
    s.ai_response_style = "balanced"
    s.language = "en_US"
    s.notifications = {
        "pushEnabled": True,
        "emailEnabled": True,
        "riskAlerts": True,
        "weeklyDigest": False,
        "aiInsights": True,
    }
    s.privacy = {
        "biometricLock": True,
        "dataCollectionOptIn": False,
        "crashReporting": True,
        "dataRetentionDays": "30 Days",
    }
    s.app_version = "v4.12.0-STABLE"
    s.created_at = _NOW
    s.updated_at = _NOW
    return s


# ---------------------------------------------------------------------------
# Test suite
# ---------------------------------------------------------------------------


class TestUserProfileAPI(unittest.TestCase):

    def setUp(self):
        self.client = TestClient(app)
        app.dependency_overrides = {}

        # Mock DB session
        self.mock_db = MagicMock()
        app.dependency_overrides[get_db] = lambda: self.mock_db

        # Build real service but with methods we can stub per test
        self.mock_service = MagicMock(spec=UserProfileService)
        app.dependency_overrides[get_user_profile_service] = lambda: self.mock_service
        app.dependency_overrides[get_auth_service] = lambda: self.mock_service

        # Reusable ORM fixtures
        self.profile = _make_profile()
        self.settings = _make_settings()

        # Wire service response builders to real static methods
        self.mock_service.profile_to_response.side_effect = (
            UserProfileService.profile_to_response
        )
        self.mock_service.settings_to_response.side_effect = (
            UserProfileService.settings_to_response
        )

    def tearDown(self):
        app.dependency_overrides = {}

    # ------------------------------------------------------------------
    # GET /user/profile
    # ------------------------------------------------------------------

    def test_get_profile_success(self):
        """GET /user/profile returns 200 with profile data."""
        self.mock_service.get_or_create_profile.return_value = self.profile

        response = self.client.get("/user/profile")
        self.assertEqual(response.status_code, 200)

        data = response.json()
        self.assertEqual(data["id"], "default")
        self.assertEqual(data["displayName"], "Test User")
        self.assertEqual(data["email"], "test@loansense.ai")
        self.assertEqual(data["phoneNumber"], "+91 99999 00000")
        self.assertIn("createdAt", data)
        self.assertIn("updatedAt", data)

    def test_get_profile_camelcase_keys(self):
        """GET /user/profile response uses camelCase keys (Flutter-compatible)."""
        self.mock_service.get_or_create_profile.return_value = self.profile

        response = self.client.get("/user/profile")
        data = response.json()

        # Verify camelCase keys are present
        self.assertIn("displayName", data)
        self.assertIn("phoneNumber", data)
        self.assertIn("avatarUrl", data)
        self.assertIn("createdAt", data)
        self.assertIn("updatedAt", data)

        # Verify snake_case keys are NOT present
        self.assertNotIn("display_name", data)
        self.assertNotIn("phone_number", data)

    def test_get_profile_server_error(self):
        """GET /user/profile returns 500 on unexpected exception."""
        self.mock_service.get_or_create_profile.side_effect = RuntimeError("DB down")

        response = self.client.get("/user/profile")
        self.assertEqual(response.status_code, 500)
        self.assertIn("Failed to fetch", response.json()["detail"])

    # ------------------------------------------------------------------
    # PATCH /user/profile
    # ------------------------------------------------------------------

    def test_patch_profile_success(self):
        """PATCH /user/profile updates and returns updated profile."""
        updated = _make_profile(display_name="Karan Dhariwal")
        self.mock_service.update_profile.return_value = updated

        response = self.client.patch(
            "/user/profile",
            json={"displayName": "Karan Dhariwal"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["displayName"], "Karan Dhariwal")

    def test_patch_profile_accepts_snake_case(self):
        """PATCH /user/profile also accepts snake_case body keys (populate_by_name)."""
        updated = _make_profile(display_name="Snake Case User")
        self.mock_service.update_profile.return_value = updated

        response = self.client.patch(
            "/user/profile",
            json={"display_name": "Snake Case User"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["displayName"], "Snake Case User")

    def test_patch_profile_no_fields_returns_422(self):
        """PATCH /user/profile with no fields returns 422."""
        response = self.client.patch("/user/profile", json={})
        self.assertEqual(response.status_code, 422)

    def test_patch_profile_server_error(self):
        """PATCH /user/profile returns 500 on service exception."""
        self.mock_service.update_profile.side_effect = RuntimeError("DB error")

        response = self.client.patch(
            "/user/profile",
            json={"displayName": "Error User"},
        )
        self.assertEqual(response.status_code, 500)

    # ------------------------------------------------------------------
    # GET /user/settings
    # ------------------------------------------------------------------

    def test_get_settings_success(self):
        """GET /user/settings returns 200 with full settings payload."""
        self.mock_service.get_or_create_settings.return_value = self.settings

        response = self.client.get("/user/settings")
        self.assertEqual(response.status_code, 200)

        data = response.json()
        self.assertEqual(data["themeMode"], "dark")
        self.assertEqual(data["aiResponseStyle"], "balanced")
        self.assertEqual(data["language"], "en_US")
        self.assertEqual(data["appVersion"], "v4.12.0-STABLE")

    def test_get_settings_camelcase_keys(self):
        """GET /user/settings uses camelCase keys for nested objects."""
        self.mock_service.get_or_create_settings.return_value = self.settings

        response = self.client.get("/user/settings")
        data = response.json()

        # Top-level camelCase
        self.assertIn("themeMode", data)
        self.assertIn("aiResponseStyle", data)
        self.assertNotIn("theme_mode", data)
        self.assertNotIn("ai_response_style", data)

        # Nested camelCase
        notif = data["notifications"]
        self.assertIn("pushEnabled", notif)
        self.assertIn("emailEnabled", notif)
        self.assertIn("riskAlerts", notif)
        self.assertIn("weeklyDigest", notif)
        self.assertIn("aiInsights", notif)

        priv = data["privacy"]
        self.assertIn("biometricLock", priv)
        self.assertIn("dataCollectionOptIn", priv)
        self.assertIn("crashReporting", priv)
        self.assertIn("dataRetentionDays", priv)

    def test_get_settings_notification_values(self):
        """GET /user/settings returns correct notification boolean values."""
        self.mock_service.get_or_create_settings.return_value = self.settings

        response = self.client.get("/user/settings")
        notif = response.json()["notifications"]

        self.assertTrue(notif["pushEnabled"])
        self.assertTrue(notif["emailEnabled"])
        self.assertTrue(notif["riskAlerts"])
        self.assertFalse(notif["weeklyDigest"])
        self.assertTrue(notif["aiInsights"])

    def test_get_settings_server_error(self):
        """GET /user/settings returns 500 on service exception."""
        self.mock_service.get_or_create_settings.side_effect = RuntimeError("crash")

        response = self.client.get("/user/settings")
        self.assertEqual(response.status_code, 500)

    # ------------------------------------------------------------------
    # PATCH /user/settings
    # ------------------------------------------------------------------

    def test_patch_settings_theme_mode(self):
        """PATCH /user/settings can update themeMode."""
        light_settings = _make_settings()
        light_settings.theme_mode = "light"
        self.mock_service.update_settings.return_value = light_settings

        response = self.client.patch(
            "/user/settings",
            json={"themeMode": "light"},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["themeMode"], "light")

    def test_patch_settings_invalid_theme_returns_422(self):
        """PATCH /user/settings with invalid themeMode returns 422."""
        response = self.client.patch(
            "/user/settings",
            json={"themeMode": "purple"},
        )
        self.assertEqual(response.status_code, 422)

    def test_patch_settings_invalid_ai_style_returns_422(self):
        """PATCH /user/settings with invalid aiResponseStyle returns 422."""
        response = self.client.patch(
            "/user/settings",
            json={"aiResponseStyle": "verbose"},
        )
        self.assertEqual(response.status_code, 422)

    def test_patch_settings_nested_notifications(self):
        """PATCH /user/settings can update nested notification fields."""
        updated = _make_settings()
        updated.notifications = {
            "pushEnabled": True,
            "emailEnabled": True,
            "riskAlerts": True,
            "weeklyDigest": True,  # toggled
            "aiInsights": True,
        }
        self.mock_service.update_settings.return_value = updated

        response = self.client.patch(
            "/user/settings",
            json={"notifications": {"weeklyDigest": True}},
        )
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.json()["notifications"]["weeklyDigest"])

    def test_patch_settings_empty_body_still_ok(self):
        """PATCH /user/settings with empty body is valid (no-op update)."""
        self.mock_service.update_settings.return_value = self.settings

        response = self.client.patch("/user/settings", json={})
        self.assertEqual(response.status_code, 200)

    # ------------------------------------------------------------------
    # DELETE /user/documents (all)
    # ------------------------------------------------------------------

    def test_delete_all_documents_success(self):
        """DELETE /user/documents deletes all docs and returns count."""
        self.mock_service.delete_all_documents.return_value = 3

        response = self.client.delete("/user/documents")
        self.assertEqual(response.status_code, 200)

        data = response.json()
        self.assertEqual(data["deletedCount"], 3)
        self.assertIn("3", data["message"])

    def test_delete_all_documents_zero(self):
        """DELETE /user/documents returns 0 when no documents exist."""
        self.mock_service.delete_all_documents.return_value = 0

        response = self.client.delete("/user/documents")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["deletedCount"], 0)

    def test_delete_all_documents_server_error(self):
        """DELETE /user/documents returns 500 on exception."""
        self.mock_service.delete_all_documents.side_effect = RuntimeError("disk error")

        response = self.client.delete("/user/documents")
        self.assertEqual(response.status_code, 500)

    # ------------------------------------------------------------------
    # DELETE /user/documents/{document_id}
    # ------------------------------------------------------------------

    def test_delete_single_document_success(self):
        """DELETE /user/documents/{id} returns 200 when document exists."""
        self.mock_service.delete_document_by_id.return_value = True
        doc_id = "8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f"

        response = self.client.delete(f"/user/documents/{doc_id}")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["deletedCount"], 1)

    def test_delete_single_document_not_found(self):
        """DELETE /user/documents/{id} returns 404 when document doesn't exist."""
        self.mock_service.delete_document_by_id.return_value = False
        doc_id = "00000000-0000-0000-0000-000000000000"

        response = self.client.delete(f"/user/documents/{doc_id}")
        self.assertEqual(response.status_code, 404)
        self.assertIn("not found", response.json()["detail"].lower())

    def test_delete_single_document_server_error(self):
        """DELETE /user/documents/{id} returns 500 on exception."""
        self.mock_service.delete_document_by_id.side_effect = RuntimeError("crash")
        doc_id = "8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f"

        response = self.client.delete(f"/user/documents/{doc_id}")
        self.assertEqual(response.status_code, 500)

    # ------------------------------------------------------------------
    # POST /user/documents/bulk-delete
    # ------------------------------------------------------------------

    def test_bulk_delete_documents_success(self):
        """POST /user/documents/bulk-delete successfully deletes specific documents."""
        # delete_document_by_id returns True (found & deleted)
        self.mock_service.delete_document_by_id.return_value = True
        doc_ids = ["11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222"]

        response = self.client.post("/user/documents/bulk-delete", json={"document_ids": doc_ids})
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["deletedCount"], 2)
        self.assertIn("2", data["message"])

        # Verify service was called for each ID
        self.assertEqual(self.mock_service.delete_document_by_id.call_count, 2)

    def test_bulk_delete_documents_partial_not_found(self):
        """POST /user/documents/bulk-delete counts only successfully deleted documents."""
        # delete_document_by_id returns True for first doc, False for second doc
        self.mock_service.delete_document_by_id.side_effect = [True, False]
        doc_ids = ["11111111-1111-1111-1111-111111111111", "99999999-9999-9999-9999-999999999999"]

        response = self.client.post("/user/documents/bulk-delete", json={"document_ids": doc_ids})
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data["deletedCount"], 1)

    def test_bulk_delete_documents_server_error(self):
        """POST /user/documents/bulk-delete returns 500 if deletion throws exception."""
        self.mock_service.delete_document_by_id.side_effect = RuntimeError("disk crash")
        doc_ids = ["11111111-1111-1111-1111-111111111111"]

        response = self.client.post("/user/documents/bulk-delete", json={"document_ids": doc_ids})
        self.assertEqual(response.status_code, 500)

    # ------------------------------------------------------------------
    # POST /auth/logout
    # ------------------------------------------------------------------

    def test_logout_success(self):
        """POST /auth/logout returns 200 with success message."""
        self.mock_service.logout.return_value = None

        response = self.client.post("/auth/logout")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["message"], "Logged out successfully")

    def test_logout_calls_service(self):
        """POST /auth/logout actually calls service.logout()."""
        self.mock_service.logout.return_value = None

        self.client.post("/auth/logout")
        self.mock_service.logout.assert_called_once()


# ---------------------------------------------------------------------------
# Service-layer unit tests (no HTTP layer)
# ---------------------------------------------------------------------------


class TestUserProfileService(unittest.TestCase):
    """Direct tests of UserProfileService without the HTTP layer."""

    def setUp(self):
        self.service = UserProfileService()
        self.db = MagicMock()

    def test_profile_to_response_camelcase(self):
        """profile_to_response() builds a UserProfileResponse with correct fields."""
        profile = _make_profile(display_name="Karan", email="k@example.com")
        resp = UserProfileService.profile_to_response(profile)

        self.assertIsInstance(resp, UserProfileResponse)
        self.assertEqual(resp.display_name, "Karan")
        self.assertEqual(resp.email, "k@example.com")
        self.assertEqual(resp.id, "default")

    def test_settings_to_response_defaults(self):
        """settings_to_response() correctly maps notification/privacy JSON."""
        settings = _make_settings()
        resp = UserProfileService.settings_to_response(settings)

        self.assertIsInstance(resp, UserSettingsResponse)
        self.assertEqual(resp.theme_mode, "dark")
        self.assertEqual(resp.ai_response_style, "balanced")
        self.assertEqual(resp.language, "en_US")
        self.assertTrue(resp.notifications.push_enabled)
        self.assertFalse(resp.notifications.weekly_digest)
        self.assertTrue(resp.privacy.biometric_lock)
        self.assertFalse(resp.privacy.data_collection_opt_in)

    def test_get_or_create_profile_creates_new(self):
        """get_or_create_profile creates a new profile when none exists."""
        self.db.query.return_value.filter.return_value.first.return_value = None

        profile = self.service.get_or_create_profile(self.db, "new_user")
        self.db.add.assert_called_once()
        self.db.commit.assert_called_once()

    def test_get_or_create_profile_returns_existing(self):
        """get_or_create_profile returns existing row without calling db.add."""
        existing = _make_profile(user_id="existing_user")
        self.db.query.return_value.filter.return_value.first.return_value = existing

        result = self.service.get_or_create_profile(self.db, "existing_user")
        self.db.add.assert_not_called()
        self.assertEqual(result.user_id, "existing_user")

    def test_get_or_create_settings_creates_new(self):
        """get_or_create_settings creates new settings row when none exists."""
        self.db.query.return_value.filter.return_value.first.return_value = None

        self.service.get_or_create_settings(self.db, "fresh_user")
        self.db.add.assert_called_once()
        self.db.commit.assert_called_once()

    def test_delete_all_documents_no_docs(self):
        """delete_all_documents returns 0 when user has no documents."""
        self.db.query.return_value.filter.return_value.all.return_value = []

        count = self.service.delete_all_documents(self.db, "default")
        self.assertEqual(count, 0)
        self.db.commit.assert_not_called()

    def test_delete_document_by_id_invalid_uuid(self):
        """delete_document_by_id returns False for malformed UUID."""
        result = self.service.delete_document_by_id(self.db, "not-a-uuid", "default")
        self.assertFalse(result)

    def test_delete_document_by_id_not_found(self):
        """delete_document_by_id returns False when document not in DB."""
        self.db.query.return_value.filter.return_value.first.return_value = None

        result = self.service.delete_document_by_id(
            self.db, "8a7b3c2d-1a2b-3c4d-5e6f-7a8b9c0d1e2f", "default"
        )
        self.assertFalse(result)


if __name__ == "__main__":
    unittest.main()
