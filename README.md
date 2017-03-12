# git2s3

## Uploads GitHub release assets to S3

This repo contains a set of resources which deal with receiving GitHub release webhooks then uploading the assets associated with that release to S3.

The following components make up this process:

- API Gateway - git2s3 - receives the webhook payload from GitHub and invokes the Lambda [git2s3-producer](src/producer/index.js) function
- Lambda - [git2s3-producer](src/producer/index.js) - receives the webhook payload from API Gateway, [validates the signature](https://github.com/ComparetheMarket/github-signature-verifier) and adds asset upload messages to a message queue
- SQS - git2s3.fifo - a FIFO message queue for asset upload messages which contain the URL needed to download the asset from GitHub  
- SQS - git2s3-dlq.fifo - a dead letter queue used to store messages that failed to be processed after 2 attempts
- CloudWatch Event - gits3 - a scheduled event which triggers once every minute invoking the [git2s3-consumer](src/consumer/index.js) Lambda function
- Lambda - [git2s3-consumer](src/consumer/index.js) - reads the messages from SQS and invokes [git2s3-worker](src/worker/index.js) Lambdas to process each asset upload
- Lambda - [git2s3-worker](src/worker/index.js) - sends an asset from GitHub to S3
- S3 Bucket - ctm-releases - used to store the release assets, organised as repo/release-tag/asset
