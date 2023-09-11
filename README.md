# apigw-trail-events
Watch API Gateway Deployment events and subscribe with lambdas


## Getting started

```bash
terraform init
terraform apply
```



## How it works

1. Create a [Cloud Trail](https://aws.amazon.com/cloudtrail/) on Write only, outputs to `/poc/write-mgt-events-trail`
2. Subscribe and filter on the logs to only retrieve events with `apigateway.amazonaws.com` as `$.eventSource` with a lambda function named `trail_event_to_log_stream`. [Source](./lambda.mjs)
3. The lambda function `trail_event_to_log_stream` needs to decompress and process the event. It will then write in a stream `/poc/api-trail-events/${restApiId}`. Each API will get its' own stream. Customize the output as you see fit or even subscribe to it.