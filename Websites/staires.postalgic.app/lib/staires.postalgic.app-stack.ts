import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import { aws_s3 as s3 } from "aws-cdk-lib";
import { aws_s3_deployment as s3deploy } from "aws-cdk-lib";
import { aws_certificatemanager as acm } from "aws-cdk-lib";
import { aws_cloudfront as cloudfront } from "aws-cdk-lib";
import { aws_cloudfront_origins as origins } from "aws-cdk-lib";
import { aws_route53 as route53 } from "aws-cdk-lib";
import { aws_route53_targets as targets } from "aws-cdk-lib";

export class StairesPostalgicAppStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const SUBDOMAIN = "staires";
    const PARENT_DOMAIN = "postalgic.app";
    const DOMAIN_NAME = `${SUBDOMAIN}.${PARENT_DOMAIN}`;
    const HOSTED_ZONE_ID = "Z0678296322S0NR3YLJXV";

    // Create an S3 bucket for static content storage
    const bucket = new s3.Bucket(this, "StaticWebsiteBucket", {
      bucketName: DOMAIN_NAME,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      versioned: true,
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED
    });

    // Deploy website files to S3 bucket
    new s3deploy.BucketDeployment(this, "DeployWebsite", {
      sources: [s3deploy.Source.asset("../temp_website")],
      destinationBucket: bucket,
      cacheControl: [
        s3deploy.CacheControl.fromString("max-age=31536000,public,immutable"),
        s3deploy.CacheControl.setPublic(),
      ],
    });

    // Create a reference to SSL certificate in ACM
    const certificateArn =
      "arn:aws:acm:us-east-1:341089094749:certificate/70a54ae8-5855-4ffe-a2d0-830209c080c8";
    const certificate = acm.Certificate.fromCertificateArn(
      this,
      "StaticSiteCertificate",
      certificateArn
    );

    // Create CloudFront Function for URL rewriting (index.html in directories)
    const urlRewriteFunction = new cloudfront.Function(this, "UrlRewriteFunction", {
      code: cloudfront.FunctionCode.fromInline(`
        function handler(event) {
          var request = event.request;
          var uri = request.uri;
          
          // Check whether the URI is missing a file extension.
          if (uri.endsWith('/')) {
            request.uri = uri + 'index.html';
          } 
          else if (!uri.includes('.')) {
            request.uri = uri + '/index.html';
          }
          
          return request;
        }
      `),
      comment: "URL rewrite function to handle directory indexes"
    });

    // Create an S3 bucket origin with Origin Access Control
    const s3Origin = origins.S3BucketOrigin.withOriginAccessControl(bucket);

    // Create a CloudFront distribution
    const distribution = new cloudfront.Distribution(this, "StaticSiteCDN", {
      domainNames: [DOMAIN_NAME],
      defaultRootObject: "index.html",
      minimumProtocolVersion: cloudfront.SecurityPolicyProtocol.TLS_V1_2_2021,
      errorResponses: [
        {
          httpStatus: 404,
          responseHttpStatus: 404,
          responsePagePath: "/error.html",
          ttl: cdk.Duration.minutes(30),
        },
        {
          httpStatus: 403,
          responseHttpStatus: 403,
          responsePagePath: "/error.html",
          ttl: cdk.Duration.minutes(30),
        }
      ],
      defaultBehavior: {
        origin: s3Origin,
        compress: true,
        allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD_OPTIONS,
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
        originRequestPolicy: cloudfront.OriginRequestPolicy.CORS_S3_ORIGIN,
        functionAssociations: [
          {
            function: urlRewriteFunction,
            eventType: cloudfront.FunctionEventType.VIEWER_REQUEST
          }
        ]
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
      target: route53.RecordTarget.fromAlias(new targets.CloudFrontTarget(distribution)),
    });

    // Output the CloudFront domain name and distribution ID
    new cdk.CfnOutput(this, "StaticSiteCDNDomain", {
      value: distribution.domainName,
      description: "CloudFront Distribution Domain Name",
    });
    
    new cdk.CfnOutput(this, "DistributionId", {
      value: distribution.distributionId,
      description: "CloudFront Distribution ID",
    });
  }
}