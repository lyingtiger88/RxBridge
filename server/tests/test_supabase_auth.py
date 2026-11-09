import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from types import SimpleNamespace
from unittest.mock import patch
from uuid import uuid4

from app import main


class SupabaseTokenVerificationTests(unittest.TestCase):
    def setUp(self):
        self.url = "https://rxbridge-example.supabase.co"
        self.user_id = str(uuid4())
        self.claims = {
            "sub": self.user_id,
            "iss": self.url + "/auth/v1",
            "aud": "authenticated",
            "role": "authenticated",
            "exp": 4_000_000_000,
            "iat": 1_700_000_000,
        }
        self.url_patch = patch.object(main.settings, "supabase_url", self.url)
        self.key_patch = patch.object(main.settings, "supabase_publishable_key", "sb_publishable_test")
        self.url_patch.start()
        self.key_patch.start()
        self.addCleanup(self.url_patch.stop)
        self.addCleanup(self.key_patch.stop)
        main._supabase_jwks_client = None

    def test_es256_token_uses_project_jwks_and_checks_audience_issuer(self):
        with patch.object(main.jwt, "get_unverified_header", return_value={"alg": "ES256", "kid": "test-kid"}), \
             patch.object(main.jwt, "PyJWKClient") as jwks, \
             patch.object(main.jwt, "decode", return_value=self.claims) as decode:
            jwks.return_value.get_signing_key_from_jwt.return_value = SimpleNamespace(key="public-key")
            result = main._verify_supabase_token("signed-token")
        self.assertEqual(result["sub"], self.user_id)
        decode.assert_called_once()
        self.assertEqual(decode.call_args.kwargs["algorithms"], ["ES256"])
        self.assertEqual(decode.call_args.kwargs["issuer"], self.url + "/auth/v1")
        self.assertEqual(decode.call_args.kwargs["audience"], "authenticated")

    def test_legacy_hs256_token_is_verified_by_supabase_auth_server(self):
        response = SimpleNamespace(status_code=200, json=lambda: {"id": self.user_id})
        with patch.object(main.jwt, "get_unverified_header", return_value={"alg": "HS256"}), \
             patch.object(main.jwt, "decode", return_value=self.claims), \
             patch.object(main.httpx, "get", return_value=response) as auth_get:
            result = main._verify_supabase_token("legacy-token")
        self.assertEqual(result["sub"], self.user_id)
        self.assertEqual(auth_get.call_args.args[0], self.url + "/auth/v1/user")
        self.assertEqual(auth_get.call_args.kwargs["headers"]["apikey"], "sb_publishable_test")

    def test_unsupported_algorithm_is_rejected(self):
        with patch.object(main.jwt, "get_unverified_header", return_value={"alg": "none"}):
            with self.assertRaises(main.HTTPException) as error:
                main._verify_supabase_token("unsigned-token")
        self.assertEqual(error.exception.status_code, 401)

    def test_auth_server_identity_mismatch_is_rejected(self):
        response = SimpleNamespace(status_code=200, json=lambda: {"id": str(uuid4())})
        with patch.object(main.jwt, "get_unverified_header", return_value={"alg": "HS256"}), \
             patch.object(main.jwt, "decode", return_value=self.claims), \
             patch.object(main.httpx, "get", return_value=response):
            with self.assertRaises(main.HTTPException) as error:
                main._verify_supabase_token("legacy-token")
        self.assertEqual(error.exception.status_code, 401)


if __name__ == "__main__":
    unittest.main()
