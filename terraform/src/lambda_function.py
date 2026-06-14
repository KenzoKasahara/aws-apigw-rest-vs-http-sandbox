import json
import os
from datetime import datetime, timezone


def lambda_handler(event, context):
    is_v2 = event.get("version") == "2.0"

    if is_v2:
        req = event.get("requestContext", {})
        http = req.get("http", {})
        meta = {
            "payloadVersion": "2.0",
            "apiType": "HTTP API",
            "apiId": req.get("apiId"),
            "stage": req.get("stage"),
            "routeKey": req.get("routeKey"),
            "method": http.get("method"),
            "path": http.get("path"),
            "sourceIp": http.get("sourceIp"),
            "requestId": req.get("requestId"),
            "timeEpoch": req.get("timeEpoch"),
        }
    else:
        req = event.get("requestContext", {})
        meta = {
            "payloadVersion": "1.0",
            "apiType": "REST API",
            "apiId": req.get("apiId"),
            "stage": req.get("stage"),
            "resourcePath": req.get("resourcePath"),
            "method": event.get("httpMethod"),
            "path": event.get("path"),
            "sourceIp": req.get("identity", {}).get("sourceIp"),
            "requestId": req.get("requestId"),
            "requestTime": req.get("requestTime"),
        }

    body = {
        "message": "ok",
        "lambdaRequestId": context.aws_request_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "meta": meta,
    }

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
