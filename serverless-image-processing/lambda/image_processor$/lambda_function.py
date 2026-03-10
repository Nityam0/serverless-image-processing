import json
import boto3
from PIL import Image
import os
import uuid
from datetime import datetime

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

DEST_BUCKET = "nityam-serverless-optimized-images-001"
TABLE_NAME = "ImageMetadata"

table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):

    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']

    download_path = '/tmp/' + key
    upload_path = '/tmp/resized-' + key

    s3.download_file(bucket, key, download_path)

    image = Image.open(download_path)
    image = image.resize((300,300))
    image.save(upload_path)

    resized_key = "resized-" + key

    s3.upload_file(upload_path, DEST_BUCKET, resized_key)

    image_id = str(uuid.uuid4())

    table.put_item(
        Item={
            "image_id": image_id,
            "original_image": key,
            "optimized_image": resized_key,
            "source_bucket": bucket,
            "destination_bucket": DEST_BUCKET,
            "processed_time": datetime.now().isoformat()
        }
    )

    return {
        'statusCode': 200,
        'body': json.dumps('Image processed and metadata stored')
    }
