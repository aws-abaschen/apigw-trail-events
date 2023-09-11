import { gunzipSync } from 'zlib';

import { CloudWatchLogs } from "@aws-sdk/client-cloudwatch-logs";
const cloudwatch = new CloudWatchLogs({});


const logGroupName = process.env.LOG_GROUP_NAME;
export const handler = async ({ awslogs: { data } }) => {
    try {
        const eventString = gunzipSync(Buffer.from(data, 'base64')).toString('utf8');

        const event = JSON.parse(JSON.parse(eventString).logEvents[0].message);
        console.log(event);
        const { requestParameters: { restApiId } } = event;

        const message = JSON.stringify({
            eventTime: new Date(event.eventTime).toISOString(),
            eventName: event.eventName,
            eventSource: event.eventSource,
            requestParameters: event.requestParameters,
            responseElements: event.responseElements
        })


        // Put the formatted log messages into the CloudWatch LogStream

        const params = {
            logGroupName: logGroupName,
            logStreamName: `${restApiId}`,
            logEvents: [{
                message,
                timestamp: Date.now(), // Assign a timestamp to each log message
            }],
        };

        try {
            await cloudwatch.putLogEvents(params);
            console.log(`Logged event for  to CloudWatch LogStream: ${restApiId}`);
        } catch (error) {
            console.error(`Error logging events to CloudWatch LogStream: ${error}`);
        }
    } catch (error) {
        console.error(error)
    }
}

