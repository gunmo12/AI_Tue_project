"""MoneyMate report API for the mobile prototype and existing clients."""

import hmac
import http.client
import json
import os
import re
from http import HTTPStatus

CATEGORIES = ('식비', '교통', '쇼핑', '구독', '카페', '기타')
MAX_BODY = 8192
MAX_AMOUNT = 1_000_000_000_000
FIELDS = {'month', 'category_totals_won', 'budget_won', 'previous_total_won'}


def amount(value):
    if type(value) is not int or not 0 <= value <= MAX_AMOUNT:
        raise ValueError('금액은 0 이상의 원 단위 정수여야 합니다.')
    return value


def report_facts(data):
    if not isinstance(data, dict) or data.keys() - FIELDS:
        raise ValueError('허용된 월별 집계 필드만 전송하세요.')
    month = data.get('month')
    if not isinstance(month, str) or not re.fullmatch(r'[1-9][0-9]{3}-(0[1-9]|1[0-2])', month):
        raise ValueError('month는 YYYY-MM 형식이어야 합니다.')
    supplied = data.get('category_totals_won')
    if not isinstance(supplied, dict) or not supplied or supplied.keys() - set(CATEGORIES):
        raise ValueError('category_totals_won에는 앱의 지출 항목과 금액을 넣어 주세요.')
    totals = {category: amount(supplied.get(category, 0)) for category in CATEGORIES}
    total = sum(totals.values())
    budget = amount(data['budget_won']) if data.get('budget_won') is not None else 0
    previous = amount(data['previous_total_won']) if data.get('previous_total_won') is not None else 0
    usage = round(total * 100 / budget, 1) if budget else None
    if not budget:
        status = '미설정'
    elif total > budget:
        status = '초과'
    elif total * 10 >= budget * 9:
        status = '주의'
    else:
        status = '여유'
    return {
        'month': month, 'category_totals_won': totals, 'total_won': total,
        'budget_won': budget or None, 'remaining_won': budget - total if budget else None,
        'budget_usage_percent': usage, 'budget_status': status,
        'previous_total_won': previous or None,
        'change_won': total - previous if previous and total else None,
        'change_percent': round((total - previous) * 100 / previous, 1) if previous and total else None,
        'top_category': max(totals, key=totals.get) if total else None,
    }


def advice_options(facts):
    options = {}
    if facts['budget_status'] in ('초과', '주의'):
        options['review_budget'] = '남은 기간의 필수 지출을 먼저 확인하고, 미룰 수 있는 결제를 점검해 보세요.'
    if facts['budget_status'] == '미설정':
        options['set_budget'] = '월 전체 예산을 정한 뒤 항목별로 쓸 수 있는 금액을 나눠 보세요.'
    if facts['category_totals_won']['구독']:
        options['review_subscriptions'] = '이번 달에 사용하지 않은 구독이 있는지 확인하고 다음 결제 전에 유지 여부를 결정해 보세요.'
    if facts['top_category']:
        options['review_top_category'] = f"지출이 가장 많은 {facts['top_category']} 항목에서 필수 지출과 조절할 수 있는 지출을 나눠 보세요."
    return options


def choose_advice(facts, options, key, model):
    if not re.fullmatch(r'gemini-[a-z0-9][a-z0-9.-]{0,79}', model):
        raise ValueError('invalid_model')
    headers = {'x-goog-api-key': key, 'Content-Type': 'application/json'}
    payload = {
        'systemInstruction': {'parts': [{'text': (
            '머니메이트의 월별 지출 집계를 읽고 지금 가장 유용한 조언 하나를 고르세요. 제공된 조언 ID만 선택하세요.'
        )}]},
        'contents': [{'role': 'user', 'parts': [
            {'text': json.dumps({'facts': facts, 'options': options}, ensure_ascii=False)}
        ]}],
        'generationConfig': {
            'candidateCount': 1,
            'maxOutputTokens': 1024,
            'responseMimeType': 'application/json',
            'responseJsonSchema': {
                'type': 'object',
                'properties': {'advice_id': {'type': 'string', 'enum': list(options)}},
                'required': ['advice_id'],
                'additionalProperties': False,
            },
        },
    }
    connection = http.client.HTTPSConnection('generativelanguage.googleapis.com', timeout=15)
    try:
        path = f'/v1beta/models/{model}:generateContent'
        connection.request('POST', path, json.dumps(payload).encode('utf-8'), headers)
        response = connection.getresponse()
        if response.status != 200:
            raise ValueError('upstream_http_error')
        raw = response.read(65537)
        if len(raw) > 65536:
            raise ValueError('upstream_response_too_large')
        candidates = json.loads(raw).get('candidates')
        if not isinstance(candidates, list) or len(candidates) != 1:
            raise ValueError('upstream_invalid_candidates')
        candidate = candidates[0]
        if candidate.get('finishReason') != 'STOP':
            raise ValueError('upstream_incomplete')
        parts = candidate['content']['parts']
        choice = json.loads(''.join(part['text'] for part in parts if not part.get('thought')))
        if not isinstance(choice, dict) or set(choice) != {'advice_id'} or choice['advice_id'] not in options:
            raise ValueError('upstream_invalid_choice')
        return choice['advice_id']
    finally:
        connection.close()


def create_report(facts):
    if facts['total_won'] == 0:
        return {'mode': 'rules', 'reason': 'no_spending', 'facts': facts,
                'advice': '지출 기록을 추가하면 소비 패턴을 분석할 수 있습니다.'}
    options = advice_options(facts)
    key = os.environ.get('GEMINI_API_KEY')
    model = os.environ.get('GEMINI_MODEL')
    if not key or not model:
        reason = 'model_not_configured'
    else:
        try:
            selected = choose_advice(facts, options, key, model)
            return {'mode': 'gemini', 'model': model, 'facts': facts, 'advice': options[selected]}
        except (OSError, http.client.HTTPException, ValueError, KeyError, TypeError, AttributeError, RecursionError):
            reason = 'model_unavailable'
    # Never include upstream response bodies, credentials or request data in errors.
    return {'mode': 'rules', 'reason': reason, 'facts': facts, 'advice': next(iter(options.values()))}


def respond(start_response, status, payload, extra_headers=()):
    body = json.dumps(payload, ensure_ascii=False).encode('utf-8')
    headers = [('Content-Type', 'application/json; charset=utf-8'), ('Cache-Control', 'no-store'),
               ('Content-Length', str(len(body))), *extra_headers]
    start_response(f'{status.value} {status.phrase}', headers)
    return [body]


def app(environ, start_response):
    path, method = environ.get('PATH_INFO'), environ.get('REQUEST_METHOD')
    allowed = {'/healthz': 'GET', '/status': 'GET', '/report': 'POST', '/app-report': 'POST'}
    if path not in allowed:
        return respond(start_response, HTTPStatus.NOT_FOUND, {'error': 'not_found'})
    if method != allowed[path]:
        return respond(start_response, HTTPStatus.METHOD_NOT_ALLOWED, {'error': 'method_not_allowed'}, [('Allow', allowed[path])])
    if path in ('/healthz', '/status'):
        return respond(start_response, HTTPStatus.OK, {'status': 'ok'})
    if path == '/report':
        access_code = os.environ.get('MONEYMATE_ACCESS_CODE', '')
        if not re.fullmatch(r'[a-f0-9]{64}', access_code):
            return respond(start_response, HTTPStatus.SERVICE_UNAVAILABLE, {'error': 'access_not_configured'})
        provided = environ.get('HTTP_AUTHORIZATION', '').encode('utf-8')
        if not hmac.compare_digest(provided, f'Bearer {access_code}'.encode('ascii')):
            return respond(start_response, HTTPStatus.UNAUTHORIZED, {'error': 'unauthorized'})
    if environ.get('CONTENT_TYPE', '').split(';')[0].strip().lower() != 'application/json':
        return respond(start_response, HTTPStatus.UNSUPPORTED_MEDIA_TYPE, {'error': 'application/json required'})
    try:
        length = int(environ.get('CONTENT_LENGTH') or 0)
    except ValueError:
        length = 0
    if length > MAX_BODY:
        return respond(start_response, HTTPStatus.REQUEST_ENTITY_TOO_LARGE, {'error': 'body_too_large'})
    if length <= 0:
        return respond(start_response, HTTPStatus.BAD_REQUEST, {'error': 'JSON 본문과 Content-Length가 필요합니다.'})
    try:
        body = environ['wsgi.input'].read(length)
        if len(body) != length:
            raise ValueError('incomplete body')
        data = json.loads(body.decode('utf-8'))
    except (ValueError, OSError, RecursionError):
        return respond(start_response, HTTPStatus.BAD_REQUEST, {'error': 'invalid_json'})
    try:
        facts = report_facts(data)
    except ValueError as error:
        return respond(start_response, HTTPStatus.BAD_REQUEST, {'error': str(error)})
    return respond(start_response, HTTPStatus.OK, create_report(facts))


if __name__ == '__main__':
    from wsgiref.simple_server import make_server

    with make_server('127.0.0.1', 8080, app) as server:
        server.serve_forever()
