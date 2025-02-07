import boto3
import time
import tempfile
import zipfile
import os

# Initialize AWS clients
athena_client = boto3.client('athena')
s3_client = boto3.client('s3')

# Query string to execute
QUERY_STRING = """
select eventTime, eventName, userIdentity.arn, userIdentity.accesskeyid, awsRegion, sourceipAddress
FROM mbm_athena_table_awsactivities
WHERE sourceipaddress NOT LIKE '%.amazonaws.com%'
    AND sourceipaddress NOT LIKE 'AWS Internal'
    AND userIdentity.arn NOT LIKE '%WizAccess-Role%'
    AND userIdentity.arn NOT LIKE '%AWSSystemsManagerDefaultEC2InstanceManagementRole%'
    AND userIdentity.arn NOT LIKE '%ec2-s3-role%'
    AND userIdentity.arn NOT LIKE '%NetworkManager%'
    AND userIdentity.arn NOT LIKE '%aws-controltower-ForwardSnsNotificationRole%'
    AND userIdentity.arn NOT LIKE '%maintenance-page-sandbox-lambda-role-turn_off%'
    AND eventName NOT LIKE '%Search%'
    AND ( eventName LIKE '%Create%' OR eventName LIKE '%Modify%' OR eventName LIKE '%Delete%' )
    AND eventName NOT LIKE '%CreateLogStream%'
order by eventTime DESC;
"""

# Database to execute the query against
DATABASE = 'mbm_database_awsactivities'

# Output location for query results
OUTPUT_BUCKET = 'mbm-aws-activity-athena-logs-from-lambda'
OUTPUT_PREFIX = 'athena-query-results/'

def lambda_handler(event, context):
    # Start query execution
    response = athena_client.start_query_execution(
        QueryString=QUERY_STRING,
        QueryExecutionContext={'Database': DATABASE},
        ResultConfiguration={
            'OutputLocation': f's3://{OUTPUT_BUCKET}/{OUTPUT_PREFIX}'
        }
    )
    query_execution_id = response['QueryExecutionId']

    # Wait for the query to complete
    while True:
        query_status = athena_client.get_query_execution(QueryExecutionId=query_execution_id)
        status = query_status['QueryExecution']['Status']['State']
        if status in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
            break
        time.sleep(5)

    if status == 'SUCCEEDED':
        # Get the query result file path
        output_file = f'{OUTPUT_PREFIX}{query_execution_id}.csv'

        # Download the file locally
        with tempfile.TemporaryDirectory() as tmpdir:
            download_path = os.path.join(tmpdir, 'query_results.csv')
            s3_client.download_file(OUTPUT_BUCKET, output_file, download_path)

            # Zip the file
            zip_path = os.path.join(tmpdir, 'query_results.zip')
            with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as zipf:
                zipf.write(download_path, 'query_results.csv')

            # Upload the zip file to S3 with the same name (overwriting existing file)
            s3_client.upload_file(zip_path, OUTPUT_BUCKET, f'{OUTPUT_PREFIX}query_results.zip')

            print(f"Zipped file successfully uploaded to S3: s3://{OUTPUT_BUCKET}/{OUTPUT_PREFIX}query_results.zip")

    else:
        print(f"Query failed with status: {status}")
