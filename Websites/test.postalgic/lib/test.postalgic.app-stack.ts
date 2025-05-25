import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import { aws_s3 as s3 } from "aws-cdk-lib";
import { aws_s3_deployment as s3deploy } from "aws-cdk-lib";
import { aws_certificatemanager as acm } from "aws-cdk-lib";
import { aws_cloudfront as cloudfront } from "aws-cdk-lib";
import { aws_cloudfront_origins as origins } from "aws-cdk-lib";

export class TestPostalgicAppStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const DOMAIN_NAME = "test.postalgic.app";

    // Create an S3 bucket to host the static website
    const bucket = new s3.Bucket(this, "StaticWebsiteBucket", {
      bucketName: DOMAIN_NAME,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      publicReadAccess: true,
      blockPublicAccess: new s3.BlockPublicAccess({
        blockPublicAcls: false,
        blockPublicPolicy: false,
        ignorePublicAcls: false,
        restrictPublicBuckets: false,
      }),
      versioned: true,
      websiteIndexDocument: "index.html",
    });

    // Deploy website files to S3 bucket
    new s3deploy.BucketDeployment(this, "DeployWebsite", {
      sources: [s3deploy.Source.asset("./temp_website")], // Path to the directory containing the index.html file
      destinationBucket: bucket,
    });

    // Create a reference to SSL certificate in ACM
    const certificateArn =
      "arn:aws:acm:us-east-1:341089094749:certificate/7cf012cf-645d-4e38-b602-bad7da918618";
    const certificate = acm.Certificate.fromCertificateArn(
      this,
      "StaticSiteCertificate",
      certificateArn
    );

    // Create a CloudFront distribution
    const cdn = new cloudfront.Distribution(this, "StaticSiteCDN", {
      domainNames: [DOMAIN_NAME],
      defaultBehavior: {
        origin: new origins.HttpOrigin(bucket.bucketWebsiteDomainName, {
          protocolPolicy: cloudfront.OriginProtocolPolicy.HTTP_ONLY,
          httpPort: 80,
          httpsPort: 443,
        }),
        allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD,
        compress: true,
      },
      certificate: certificate,
    });

    // Output the CloudFront domain name
    new cdk.CfnOutput(this, "StaticSiteCDNDomain", {
      value: cdn.domainName,
    });
  }
}
