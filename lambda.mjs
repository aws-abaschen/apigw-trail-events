import { gunzipSync } from 'zlib';

import { CloudWatchLogs } from "@aws-sdk/client-cloudwatch-logs";
const cloudwatch = new CloudWatchLogs({});


const logGroupName = process.env.LOG_GROUP_NAME;
export const handler = async ({ awslogs: { data } }) => {
    try {
        const eventString = await gunzipSync(Buffer.from(data, 'base64')).toString('utf8');

        // keep promise order
        // https://stackoverflow.com/a/49499491
        await JSON.parse(eventString).logEvents.reduce(async (promise, e) => {
            await promise;
            const event = JSON.parse(e.message);
            console.log(event);
            const { requestParameters, responseElements, eventName } = event;
            const { restApiId, functionName } = requestParameters;
            try {
                if (restApiId) {
                    switch (eventName) {
                        case "CreateResource": await log(`Created resource ${responseElements.path}`, restApiId); break;
                        case "DeleteResource": await log(`Deleted resource with id ${requestParameters.resourceId}`, restApiId); break;
                        case "PutMethod": await log(`Adding method ${requestParameters.httpMethod} to resource ${requestParameters.resourceId}, authorizationType: ${requestParameters.putMethodInput.authorizationType}, apiKeyRequired: ${requestParameters.putMethodInput.apiKeyRequired}`, restApiId); break;
                        case "UpdateMethod": await log(`Updating method ${requestParameters.httpMethod} of resource ${requestParameters.resourceId}, Input: ${JSON.stringify(requestParameters.updateMethodInput)}`, restApiId); break;
                        case "PutIntegration": await log(`Updating method ${requestParameters.httpMethod} of resource ${requestParameters.resourceId}, Input: ${JSON.stringify(requestParameters.putIntegrationInput)}`, restApiId); break;
                        case "UpdateMethodResponse": await log(`Updating method response ${requestParameters.httpMethod} of resource ${requestParameters.resourceId}, Input: ${JSON.stringify(requestParameters.updateMethodResponseInput)}`, restApiId); break;
                        case "UpdateStage": await log(`Updating stage '${requestParameters.stageName}', Input: ${JSON.stringify(requestParameters.updateStageInput)}`, restApiId); break;
                        case "CreateDeployment": await log(`New deployment of stage '${requestParameters.createDeploymentInput.stageName}'`, restApiId); break;
                        default: await log(`${eventName} - ${JSON.stringify(requestParameters)}`, restApiId);
                    }
                } else {
                    switch (eventName) {
                        case "CreateFunctionUrlConfig": await log(`Created functionUrlConfig with url: ${responseElements.functionUrl}, auth_type: ${responseElements.authType}`, functionName); break;
                        case "DeleteFunctionUrlConfig": await log(`Deleted functionUrlConfig for ${functionName}`, functionName); break;
                        case "UpdateFunctionUrlConfig": await log(`Created functionUrlConfig with url: ${responseElements.functionUrl}, auth_type: ${responseElements.authType}`, functionName); break;
                        default: await log(`${eventName} - ${JSON.stringify(requestParameters)}`, functionName);
                    }
                }

            } catch (error) {
                console.error(`Error logging events to CloudWatch LogStream: ${error}`);
            }
        }, Promise.resolve());

    } catch (error) {
        console.error(error)
    }
}


async function log(message, Id) {
    const params = {
        logGroupName,
        logStreamName: `${Id}`,
        logEvents: [{
            message,
            timestamp: Date.now()
        }],
    };
    await cloudwatch.putLogEvents(params);
}
