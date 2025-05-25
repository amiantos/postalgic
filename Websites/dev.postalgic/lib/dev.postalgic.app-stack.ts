import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import { aws_s3 as s3 } from "aws-cdk-lib";
import { aws_s3_deployment as s3deploy } from "aws-cdk-lib";
import { aws_certificatemanager as acm } from "aws-cdk-lib";
import { aws_cloudfront as cloudfront } from "aws-cdk-lib";
import { aws_cloudfront_origins as origins } from "aws-cdk-lib";
import { aws_route53 as route53 } from "aws-cdk-lib";
import { aws_route53_targets as targets } from "aws-cdk-lib";

export class DevPostalgicAppStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const SUBDOMAIN = "dev";
    const PARENT_DOMAIN = "postalgic.app";
    const DOMAIN_NAME = `${SUBDOMAIN}.${PARENT_DOMAIN}`;
    const HOSTED_ZONE_ID = "Z0678296322S0NR3YLJXV";

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
      sources: [s3deploy.Source.asset("../temp_website")], // Path to the directory containing the index.html file
      destinationBucket: bucket,
    });

    // Create a reference to SSL certificate in ACM
    const certificateArn =
      "arn:aws:acm:us-east-1:341089094749:certificate/70a54ae8-5855-4ffe-a2d0-830209c080c8";
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

    // Import the hosted zone
    const hostedZone = route53.HostedZone.fromHostedZoneAttributes(this, "HostedZone", {
      hostedZoneId: HOSTED_ZONE_ID,
      zoneName: PARENT_DOMAIN, // Parent domain of your subdomain
    });

    // Create an A record for the subdomain
    new route53.ARecord(this, "SubdomainRecord", {
      zone: hostedZone,
      recordName: SUBDOMAIN, // Just the subdomain part
      target: route53.RecordTarget.fromAlias(new targets.CloudFrontTarget(cdn)),
      ttl: cdk.Duration.minutes(5),
    });

    // Output the CloudFront domain name
    new cdk.CfnOutput(this, "StaticSiteCDNDomain", {
      value: cdn.domainName,
    });
  }
}
