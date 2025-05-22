import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import { aws_s3 as s3 } from "aws-cdk-lib";
import { aws_certificatemanager as acm } from "aws-cdk-lib";
import { aws_cloudfront as cloudfront } from "aws-cdk-lib";
import { aws_cloudfront_origins as origins } from "aws-cdk-lib";
import { aws_route53 as route53 } from "aws-cdk-lib";
import { aws_route53_targets as targets } from "aws-cdk-lib";

export class BradPostalgicAppStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const SUBDOMAIN = "brad";
    const PARENT_DOMAIN = "postalgic.app";
    const DOMAIN_NAME = `${SUBDOMAIN}.${PARENT_DOMAIN}`;
    const HOSTED_ZONE_ID = "Z0678296322S0NR3YLJXV";
    const REDIRECT_TARGET = "https://ihavebeenfloated.org";

    // Create an S3 bucket configured for website redirect
    const bucket = new s3.Bucket(this, "RedirectBucket", {
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
      websiteRedirect: {
        hostName: "ihavebeenfloated.org",
        protocol: s3.RedirectProtocol.HTTPS,
      },
    });

    // Create a reference to SSL certificate in ACM
    const certificateArn =
      "arn:aws:acm:us-east-1:341089094749:certificate/70a54ae8-5855-4ffe-a2d0-830209c080c8";
    const certificate = acm.Certificate.fromCertificateArn(
      this,
      "RedirectCertificate",
      certificateArn
    );

    // Create a CloudFront distribution
    const cdn = new cloudfront.Distribution(this, "RedirectCDN", {
      domainNames: [DOMAIN_NAME],
      defaultBehavior: {
        origin: new origins.HttpOrigin(bucket.bucketWebsiteDomainName, {
          protocolPolicy: cloudfront.OriginProtocolPolicy.HTTP_ONLY,
          httpPort: 80,
          httpsPort: 443,
        }),
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD,
        compress: true,
      },
      certificate: certificate,
    });

    // Import the hosted zone
    const hostedZone = route53.HostedZone.fromHostedZoneAttributes(this, "HostedZone", {
      hostedZoneId: HOSTED_ZONE_ID,
      zoneName: PARENT_DOMAIN,
    });

    // Create an A record for the subdomain
    new route53.ARecord(this, "SubdomainRecord", {
      zone: hostedZone,
      recordName: SUBDOMAIN,
      target: route53.RecordTarget.fromAlias(new targets.CloudFrontTarget(cdn)),
      ttl: cdk.Duration.minutes(5),
    });

    // Output the CloudFront domain name and redirect target
    new cdk.CfnOutput(this, "RedirectCDNDomain", {
      value: cdn.domainName,
    });
    
    new cdk.CfnOutput(this, "RedirectTarget", {
      value: REDIRECT_TARGET,
    });
  }
}