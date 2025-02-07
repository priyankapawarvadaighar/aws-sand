# Define the provider
provider "aws" {
  region = "us-east-2"
}
data "aws_iam_role" "existing_role"{
  name = "mbm-LambdaAthenaQueryRole"
}


resource "aws_s3_bucket" "output_bucket" { 
    bucket = var.output_bucket_name
}

# Create Glue Database
resource "aws_glue_catalog_database" "database_athena" {
  name = var.glue_database
}

# Create Glue Table
resource "aws_glue_catalog_table" "example" {
  database_name = aws_glue_catalog_database.example.name
  name          = var.glue_table
  parameters = {
    EXTERNAL              = "TRUE"
  }
 
  storage_descriptor {
    location      = "s3://aws-controltower-logs-331029515692-us-east-2/o-c2ahh0nqtr/AWSLogs/o-c2ahh0nqtr/982061730973/CloudTrail/"
    input_format  = "com.amazon.emr.cloudtrail.CloudTrailInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
 
    ser_de_info {
      name                  = "CloudTrailSerDe"
      serialization_library = "org.openx.data.jsonserde.JsonSerDe"
      parameters = {
        "serialization.format" = 1
      }
    }
 
    columns {
      name = "eventversion"
      type = "string"
    }
    columns {
      name = "useridentity"
      type = "struct<type:string,principalid:string,arn:string,accountid:string,invokedby:string,accesskeyid:string,userName:string,sessioncontext:struct<attributes:struct<mfaauthenticated:string,creationdate:string>,sessionissuer:struct<type:string,principalId:string,arn:string,accountId:string,userName:string>>>"
    }
    columns {
      name = "eventtime"
      type = "string"
    }
    columns {
      name = "eventsource"
      type = "string"
    }
    columns {
      name = "eventname"
      type = "string"
    }
    columns {
      name = "awsregion"
      type = "string"
    }
    columns {
      name = "sourceipaddress"
      type = "string"
    }
    columns {
      name = "useragent"
      type = "string"
    }
    columns {
      name = "errorcode"
      type = "string"
    }
    columns {
      name = "errormessage"
      type = "string"
    }
    columns {
      name = "requestparameters"
      type = "string"
    }
    columns {
      name = "responseelements"
      type = "string"
    }
    columns {
      name = "additionaleventdata"
      type = "string"
    }
    columns {
      name = "requestid"
      type = "string"
    }
    columns {
      name = "eventid"
      type = "string"
    }
    columns {
      name = "resources"
      type = "array<struct<arn:string,accountid:string,type:string>>"
    }
    columns {
      name = "eventtype"
      type = "string"
    }
    columns {
      name = "apiversion"
      type = "string"
    }
    columns {
      name = "readonly"
      type = "string"
    }
    columns {
      name = "recipientaccountid"
      type = "string"
    }
    columns {
      name = "serviceeventdetails"
      type = "string"
    }
    columns {
      name = "sharedeventid"
      type = "string"
    }
    columns {
      name = "vpcendpointid"
      type = "string"
    }
    columns {
      name = "vpcendpointaccountid"
      type = "string"
    }
    columns {
      name = "eventcategory"
      type = "string"
    }
    columns {
      name = "addendum"
      type = "struct<reason:string,updatedfields:string,originalrequestid:string,originaleventid:string>"
    }
    columns {
      name = "sessioncredentialfromconsole"
      type = "string"
    }
    columns {
      name = "edgedevicedetails"
      type = "string"
    }
    columns {
      name = "tlsdetails"
      type = "struct<tlsversion:string,ciphersuite:string,clientprovidedhostheader:string>"
    }
  }
}


data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda.zip"
}


# Create Lambda Function
resource "aws_lambda_function" "athena_query_function" {
  filename         = "lambda.zip"    
  function_name    = "athena_query_function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler" 
  runtime          = "python3.9"  # Update with your runtime
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 900
}


# CloudWatch Event Rule to trigger the Lambda function every minute
resource "aws_cloudwatch_event_rule" "every_minute" {
  name                = "every_minute"
  schedule_expression = "rate(1 day)"
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.every_minute.name
  target_id = "athena_lambda"
  arn       = aws_lambda_function.athena_query_function.arn
}

# Grant CloudWatch permission to invoke the Lambda function
resource "aws_lambda_permission" "cloudwatch_allow" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.athena_query_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_minute.arn
}
