import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import { aws_s3 as s3 } from "aws-cdk-lib";
import { aws_s3_deployment as s3deploy } from "aws-cdk-lib";
import { aws_certificatemanager as acm } from "aws-cdk-lib";
import { aws_cloudfront as cloudfront } from "aws-cdk-lib";
import { aws_cloudfront_origins as origins } from "aws-cdk-lib";
import { aws_route53 as route53 } from "aws-cdk-lib";
import { aws_route53_targets as targets } from "aws-cdk-lib";
import { aws_iam as iam } from "aws-cdk-lib";

export class AppreviewPostalgicStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const SUBDOMAIN = "appreview";
    const PARENT_DOMAIN = "postalgic.app";
    const DOMAIN_NAME = `${SUBDOMAIN}.${PARENT_DOMAIN}`;
    const HOSTED_ZONE_ID = "Z0678296322S0NR3YLJXV";

    // Create a bucket for the main domain
    const mainBucket = new s3.Bucket(this, "MainWebsiteBucket", {
      bucketName: DOMAIN_NAME.toLowerCase(),
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

    // Deploy temp website files to bucket
    new s3deploy.BucketDeployment(this, "DeployWebsite", {
      sources: [s3deploy.Source.asset("../temp_website")],
      destinationBucket: mainBucket,
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

    // Import the hosted zone
    const hostedZone = route53.HostedZone.fromHostedZoneAttributes(this, "HostedZone", {
      hostedZoneId: HOSTED_ZONE_ID,
      zoneName: PARENT_DOMAIN, // Parent domain of your subdomain
    });

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

    // Create an S3 bucket origin with Origin Access Control for main site
    const mainSiteOrigin = origins.S3BucketOrigin.withOriginAccessControl(mainBucket);

    // Create a CloudFront distribution for the main domain
    const mainDistribution = new cloudfront.Distribution(this, "MainSiteCDN", {
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
        origin: mainSiteOrigin,
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

    // Create A record for subdomain
    new route53.ARecord(this, "ApexDomainRecord", {
      zone: hostedZone,
      recordName: SUBDOMAIN,
      target: route53.RecordTarget.fromAlias(new targets.CloudFrontTarget(mainDistribution)),
    });

    // Create IAM user for S3 and CloudFront access
    const deploymentUser = new iam.User(this, "DeploymentUser", {
      userName: `${SUBDOMAIN}-postalgic-deployment-user`
    });

    // Create policy for S3 bucket access
    const s3Policy = new iam.Policy(this, "S3AccessPolicy", {
      policyName: `${SUBDOMAIN}-postalgic-s3-access`,
      statements: [
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket"
          ],
          resources: [
            mainBucket.bucketArn,
            `${mainBucket.bucketArn}/*`
          ]
        })
      ]
    });

    // Create policy for CloudFront invalidation
    const cloudfrontPolicy = new iam.Policy(this, "CloudFrontAccessPolicy", {
      policyName: `${SUBDOMAIN}-postalgic-cloudfront-access`,
      statements: [
        new iam.PolicyStatement({
          effect: iam.Effect.ALLOW,
          actions: [
            "cloudfront:CreateInvalidation"
          ],
          resources: [
            `arn:aws:cloudfront::${this.account}:distribution/${mainDistribution.distributionId}`
          ]
        })
      ]
    });

    // Attach policies to user
    deploymentUser.attachInlinePolicy(s3Policy);
    deploymentUser.attachInlinePolicy(cloudfrontPolicy);

    // Create access key for the user
    const accessKey = new iam.AccessKey(this, "DeploymentUserAccessKey", {
      user: deploymentUser
    });

    // Output the CloudFront domain names
    new cdk.CfnOutput(this, "MainSiteDomain", {
      value: mainDistribution.domainName,
      description: "Main Site CloudFront Distribution Domain",
    });

    // Output deployment credentials
    new cdk.CfnOutput(this, "DeploymentAccessKeyId", {
      value: accessKey.accessKeyId,
      description: "Access Key ID for deployment user",
    });

    new cdk.CfnOutput(this, "DeploymentSecretAccessKey", {
      value: accessKey.secretAccessKey.unsafeUnwrap(),
      description: "Secret Access Key for deployment user",
    });

    new cdk.CfnOutput(this, "S3BucketName", {
      value: mainBucket.bucketName,
      description: "S3 bucket name for website files",
    });

    new cdk.CfnOutput(this, "CloudFrontDistributionId", {
      value: mainDistribution.distributionId,
      description: "CloudFront distribution ID for cache invalidation",
    });
  }
}
