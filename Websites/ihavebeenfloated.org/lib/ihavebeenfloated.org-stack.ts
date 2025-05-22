import * as cdk from "aws-cdk-lib";
import { Construct } from "constructs";
import { aws_s3 as s3 } from "aws-cdk-lib";
import { aws_s3_deployment as s3deploy } from "aws-cdk-lib";
import { aws_certificatemanager as acm } from "aws-cdk-lib";
import { aws_cloudfront as cloudfront } from "aws-cdk-lib";
import { aws_cloudfront_origins as origins } from "aws-cdk-lib";
import { aws_route53 as route53 } from "aws-cdk-lib";
import { aws_route53_targets as targets } from "aws-cdk-lib";

export class IhavebeenfloatedOrgStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    const DOMAIN_NAME = "ihavebeenfloated.org";
    const WWW_DOMAIN = `www.${DOMAIN_NAME}`;
    const HOSTED_ZONE_ID = "Z01427533E5G3OMJWR5JT";

    // Create a bucket for the main domain
    const mainBucket = new s3.Bucket(this, "MainWebsiteBucket", {
      bucketName: DOMAIN_NAME.toLowerCase(),
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      versioned: true,
      objectOwnership: s3.ObjectOwnership.BUCKET_OWNER_ENFORCED
    });

    // Create redirect bucket for www subdomain
    const wwwBucket = new s3.Bucket(this, "WwwRedirectBucket", {
      bucketName: WWW_DOMAIN.toLowerCase(),
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      encryption: s3.BucketEncryption.S3_MANAGED,
      websiteRedirect: {
        hostName: DOMAIN_NAME,
        protocol: s3.RedirectProtocol.HTTPS
      }
    });

    // Deploy website files to main bucket
    new s3deploy.BucketDeployment(this, "DeployWebsite", {
      sources: [s3deploy.Source.asset("../temp_website")],
      destinationBucket: mainBucket,
      cacheControl: [
        s3deploy.CacheControl.fromString("max-age=31536000,public,immutable"),
        s3deploy.CacheControl.setPublic(),
      ],
    });

    // Import the hosted zone for the domain
    const hostedZone = route53.HostedZone.fromHostedZoneAttributes(this, "HostedZone", {
      hostedZoneId: HOSTED_ZONE_ID,
      zoneName: DOMAIN_NAME,
    });

    // Create or import SSL certificate for both domains
    const certificate = new acm.Certificate(this, "SiteCertificate", {
      domainName: DOMAIN_NAME,
      subjectAlternativeNames: [WWW_DOMAIN],
      validation: acm.CertificateValidation.fromDns(hostedZone),
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

    // Create CloudFront distribution for the www subdomain that will redirect to the apex domain
    const wwwDistribution = new cloudfront.Distribution(this, "WwwRedirectCDN", {
      domainNames: [WWW_DOMAIN],
      defaultRootObject: "index.html", // Not used with a redirect
      minimumProtocolVersion: cloudfront.SecurityPolicyProtocol.TLS_V1_2_2021,
      defaultBehavior: {
        origin: origins.S3BucketOrigin.withOriginAccessControl(wwwBucket),
        compress: true,
        viewerProtocolPolicy: cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        cachePolicy: cloudfront.CachePolicy.CACHING_OPTIMIZED,
      },
      certificate: certificate,
    });

    // Create A record for apex domain
    new route53.ARecord(this, "ApexDomainRecord", {
      zone: hostedZone,
      recordName: DOMAIN_NAME,
      target: route53.RecordTarget.fromAlias(new targets.CloudFrontTarget(mainDistribution)),
    });

    // Create A record for www subdomain
    new route53.ARecord(this, "WwwDomainRecord", {
      zone: hostedZone,
      recordName: "www",
      target: route53.RecordTarget.fromAlias(new targets.CloudFrontTarget(wwwDistribution)),
    });

    // Output the CloudFront domain names
    new cdk.CfnOutput(this, "MainSiteDomain", {
      value: mainDistribution.domainName,
      description: "Main Site CloudFront Distribution Domain",
    });
    
    new cdk.CfnOutput(this, "WwwRedirectDomain", {
      value: wwwDistribution.domainName,
      description: "WWW Redirect CloudFront Distribution Domain",
    });
  }
}
