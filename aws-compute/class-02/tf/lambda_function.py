import json


def lambda_handler(event, context):
    name = event.get("name", "student")

    message = f"Hello, {name}! This response came from AWS Lambda."

    print(json.dumps({
        "requestId": context.aws_request_id,
        "functionName": context.function_name,
        "eventName": name
    }))

    return {
        "statusCode": 200,
        "body": json.dumps({
            "message": message,
            "function": context.function_name
        })
    }