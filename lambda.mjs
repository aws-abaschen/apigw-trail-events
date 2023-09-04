import { gunzipSync } from 'zlib';
import { ApiGatewayV2Client, GetDeploymentCommand } from "@aws-sdk/client-apigatewayv2";

const client = new ApiGatewayV2Client({});

// { // GetDeploymentResponse
//   AutoDeployed: true || false,
//   CreatedDate: new Date("TIMESTAMP"),
//   DeploymentId: "STRING_VALUE",
//   DeploymentStatus: "PENDING" || "FAILED" || "DEPLOYED",
//   DeploymentStatusMessage: "STRING_VALUE",
//   Description: "STRING_VALUE",
// };

export const handler = async ({ awslogs: { data } }) => {
    try {
        const eventString = gunzipSync(Buffer.from(data, 'base64')).toString('utf8');

        const event = JSON.parse(JSON.parse(eventString).logEvents[0].message);
        console.log(event);
        const { responseElements: { deploymentUpdate: { restApiId, deploymentId } } } = event;

        const input = {
            ApiId: restApiId,
            DeploymentId: deploymentId
        };
        const command = new GetDeploymentCommand(input);
        const response = await client.send(command);
        console.log(JSON.stringify(response));
    } catch (error) {
        console.error(error)
    }
}