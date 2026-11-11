# API Contract — v1

Base URL: `http://127.0.0.1:8080`  
JSON media type: `application/json`  
Mutating operations require `Authorization: Bearer <API_TOKEN>`.

## Resource schema

```json
{
  "title": "FIM Review",
  "description": "Review a protected file baseline",
  "priority": "high"
}
```

- `title`: required string, 1–120 Unicode characters.
- `description`: optional string, at most 2,000 Unicode characters; defaults to empty.
- `priority`: optional enum `low`, `normal`, or `high`; defaults to `normal`.
- Unknown fields are rejected.

## Endpoints

| Method | Path | Auth | Success |
|---|---|---:|---:|
| GET | `/api/health` | No | 200 |
| GET | `/api/items` | No | 200 |
| POST | `/api/items` | Yes | 201 + Location |
| GET | `/api/items/{uuid}` | No | 200 |
| PUT | `/api/items/{uuid}` | Yes | 200 |
| DELETE | `/api/items/{uuid}` | Yes | 204 empty body |
| OPTIONS | supported path | No | 204 |

`GET /api/items` supports `?q=text&limit=1`, with `limit` constrained to 1–100.

## Error mapping

| Status | Error code | Meaning |
|---:|---|---|
| 400 | `INVALID_JSON`, `EMPTY_BODY`, `INVALID_LIMIT` | Malformed request syntax/query |
| 401 | `UNAUTHORIZED` | Missing or invalid Bearer token |
| 404 | `ROUTE_NOT_FOUND`, `ITEM_NOT_FOUND` | Route/resource does not exist |
| 405 | `METHOD_NOT_ALLOWED` | Method is not allowed; inspect `Allow` |
| 413 | `PAYLOAD_TOO_LARGE` | Request body exceeds 64 KiB |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | Content-Type is not application/json |
| 422 | `INVALID_TITLE`, `INVALID_DESCRIPTION`, `INVALID_PRIORITY`, `UNKNOWN_FIELDS` | JSON parsed but violates schema |
| 503 | `AUTH_NOT_CONFIGURED` | API_TOKEN is missing; writes fail closed |
| 500 | `INTERNAL_SERVER_ERROR` | Unexpected server failure; details stay in server log |

## Response envelope

Success responses use `success`, `request_id`, and `data`. Errors use `success`, `request_id`, and an `error` object with `code` and `message`. A 204 response intentionally has no body.
