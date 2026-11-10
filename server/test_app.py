import io
import json
import os
import unittest
from pathlib import Path
from unittest.mock import patch

from app import MAX_BODY, app

SAMPLE = json.loads(Path(__file__).with_name('sample-report.json').read_text(encoding='utf-8'))
GEMINI_ENV = {'GEMINI_API_KEY': 'test-key', 'GEMINI_MODEL': 'gemini-3.5-flash-lite'}
ACCESS_CODE = 'a' * 64


def request(data=None, *, path='/report', method='POST', body=None, content_type='application/json',
            authorization=f'Bearer {ACCESS_CODE}', access_code=ACCESS_CODE):
    raw = json.dumps(data).encode() if body is None else body
    response = []
    with patch.dict(os.environ, {'MONEYMATE_ACCESS_CODE': access_code}):
        chunks = app({'PATH_INFO': path, 'REQUEST_METHOD': method, 'CONTENT_TYPE': content_type,
                      'CONTENT_LENGTH': str(len(raw)), 'wsgi.input': io.BytesIO(raw),
                      'HTTP_AUTHORIZATION': authorization},
                     lambda status, headers: response.extend([int(status[:3]), dict(headers)]))
    return response[0], response[1], json.loads(b''.join(chunks))


class ReportTests(unittest.TestCase):
    def test_app_report_accepts_only_valid_aggregates_without_access_code(self):
        status, _, body = request(SAMPLE, path='/app-report', authorization='', access_code='')
        self.assertEqual((status, body['facts']['total_won']), (200, 862000))
        status, _, _ = request({**SAMPLE, 'memo': 'sample'}, path='/app-report', authorization='')
        self.assertEqual(status, 400)
        self.assertEqual(request(SAMPLE, authorization='')[0], 401)

    def test_report_rejects_unauthenticated_requests_before_analysis(self):
        with patch('app.create_report') as create:
            self.assertEqual(request(SAMPLE, authorization='')[0], 401)
            self.assertEqual(request(SAMPLE, authorization='Bearer wrong')[0], 401)
            self.assertEqual(request(SAMPLE, access_code='')[0], 503)
            create.assert_not_called()

    def test_health(self):
        for path in ('/status', '/healthz'):
            with self.subTest(path=path):
                status, _, body = request(path=path, method='GET', authorization='', access_code='')
                self.assertEqual((status, body), (200, {'status': 'ok'}))

    @patch.dict(os.environ, {}, clear=True)
    def test_sample_without_credentials(self):
        status, headers, body = request(SAMPLE)
        self.assertEqual(status, 200)
        self.assertEqual(headers['Cache-Control'], 'no-store')
        self.assertEqual(body['reason'], 'model_not_configured')
        facts = body['facts']
        self.assertEqual((facts['total_won'], facts['remaining_won'], facts['budget_usage_percent']), (862000, 238000, 78.4))
        self.assertEqual((facts['change_won'], facts['change_percent']), (-63000, -6.8))

    def test_privacy_and_validation(self):
        cases = [{**SAMPLE, 'transactions': []}, {**SAMPLE, 'month': '2026-13'},
                 {**SAMPLE, 'category_totals_won': {'식비': True}},
                 {**SAMPLE, 'category_totals_won': {'카드번호': 100}},
                 {**SAMPLE, 'budget_won': -1}]
        with patch('app.choose_advice') as call:
            for case in cases:
                with self.subTest(case=case):
                    self.assertEqual(request(case)[0], 400)
            call.assert_not_called()

    def test_invalid_payload(self):
        self.assertEqual(request(body=b'{broken')[0], 400)
        self.assertEqual(request(body=b' ' * (MAX_BODY + 1))[0], 413)
        self.assertEqual(request(SAMPLE, content_type='text/plain')[0], 415)
        self.assertEqual(request(SAMPLE, method='GET')[0], 405)

    @patch.dict(os.environ, {}, clear=True)
    def test_budget_thresholds_and_no_comparison(self):
        for spent, expected in [(899, '여유'), (900, '주의'), (1000, '주의'), (1001, '초과')]:
            with self.subTest(spent=spent):
                _, _, body = request({'month': '2026-11', 'category_totals_won': {'식비': spent}, 'budget_won': 1000})
                self.assertEqual(body['facts']['budget_status'], expected)
                self.assertIsNone(body['facts']['change_percent'])

    @patch.dict(os.environ, GEMINI_ENV, clear=True)
    def test_no_spending_does_not_call_model(self):
        with patch('app.choose_advice') as call:
            _, _, body = request({'month': '2026-11', 'category_totals_won': {'식비': 0}})
            self.assertEqual(body['reason'], 'no_spending')
            call.assert_not_called()

    @patch.dict(os.environ, GEMINI_ENV, clear=True)
    @patch('app.http.client.HTTPSConnection')
    def test_provider_request_and_response(self, https):
        conn = https.return_value
        response = conn.getresponse.return_value
        response.status = 200
        response.read.return_value = json.dumps({'candidates': [{
            'finishReason': 'STOP',
            'content': {'parts': [
                {'thought': True, 'text': 'internal reasoning'},
                {'text': '{"advice_id":'},
                {'text': '"review_subscriptions"}'},
            ]},
        }]}).encode()
        status, _, body = request(SAMPLE)
        self.assertEqual((status, body['mode'], body['model']), (200, 'gemini', 'gemini-3.5-flash-lite'))
        self.assertIn('구독', body['advice'])
        https.assert_called_once_with('generativelanguage.googleapis.com', timeout=15)
        method, path, raw, headers = conn.request.call_args.args
        self.assertEqual((method, path), ('POST', '/v1beta/models/gemini-3.5-flash-lite:generateContent'))
        self.assertEqual(headers['x-goog-api-key'], 'test-key')
        self.assertNotIn(b'test-key', raw)
        payload = json.loads(raw)
        sent = json.loads(payload['contents'][0]['parts'][0]['text'])
        self.assertEqual(sent['facts']['total_won'], 862000)
        self.assertNotIn('transactions', sent['facts'])
        config = payload['generationConfig']
        self.assertEqual(config['responseMimeType'], 'application/json')
        self.assertEqual(config['responseJsonSchema']['properties']['advice_id']['enum'], list(sent['options']))
        conn.close.assert_called_once()

    @patch.dict(os.environ, GEMINI_ENV, clear=True)
    @patch('app.http.client.HTTPSConnection')
    def test_provider_failure_or_unapproved_output(self, https):
        conn = https.return_value
        response = conn.getresponse.return_value
        cases = {
            'invalid_choice': (200, {'candidates': [{'finishReason': 'STOP', 'content': {
                'parts': [{'text': '{"advice_id":"arbitrary"}'}],
            }}]}),
            'blocked': (200, {'promptFeedback': {'blockReason': 'SAFETY'}}),
            'truncated': (200, {'candidates': [{'finishReason': 'MAX_TOKENS'}]}),
            'quota_error': (429, {'error': {'message': 'private diagnostic'}}),
            'timeout': (None, {}),
        }
        for scenario, (http_status, payload) in cases.items():
            with self.subTest(scenario=scenario):
                response.status = http_status
                response.read.return_value = json.dumps(payload).encode()
                conn.getresponse.side_effect = TimeoutError('private diagnostic') if http_status is None else None
                status, _, body = request(SAMPLE)
                self.assertEqual((status, body['mode'], body['reason']), (200, 'rules', 'model_unavailable'))
                self.assertEqual(body['facts']['total_won'], 862000)
                self.assertNotIn('private diagnostic', json.dumps(body))
