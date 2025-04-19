//
//  BlogAwsConfigView.swift
//  Postalgic
//
//  Created by Brad Root on 4/19/25.
//

import SwiftUI
import SwiftData

struct BlogAwsConfigView: View {
    @Bindable var blog: Blog
    @Environment(\.dismiss) private var dismiss
    
    // Available AWS regions
    let awsRegions = [
        "us-east-1": "US East (N. Virginia)",
        "us-east-2": "US East (Ohio)",
        "us-west-1": "US West (N. California)",
        "us-west-2": "US West (Oregon)",
        "ca-central-1": "Canada (Central)",
        "eu-west-1": "EU (Ireland)",
        "eu-west-2": "EU (London)",
        "eu-west-3": "EU (Paris)",
        "eu-central-1": "EU (Frankfurt)",
        "ap-northeast-1": "Asia Pacific (Tokyo)",
        "ap-northeast-2": "Asia Pacific (Seoul)",
        "ap-northeast-3": "Asia Pacific (Osaka)",
        "ap-southeast-1": "Asia Pacific (Singapore)",
        "ap-southeast-2": "Asia Pacific (Sydney)",
        "ap-south-1": "Asia Pacific (Mumbai)",
        "sa-east-1": "South America (São Paulo)"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("AWS Region")) {
                    Picker("Region", selection: Binding(
                        get: { blog.awsRegion ?? "us-east-1" },
                        set: { blog.awsRegion = $0 }
                    )) {
                        ForEach(awsRegions.keys.sorted(), id: \.self) { key in
                            Text(awsRegions[key] ?? key)
                                .tag(key)
                        }
                    }
                }
                
                Section(header: Text("AWS S3 Configuration")) {
                    TextField("S3 Bucket Name", text: Binding(
                        get: { blog.awsS3Bucket ?? "" },
                        set: { blog.awsS3Bucket = $0.isEmpty ? nil : $0 }
                    ))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .textContentType(.URL)
                }
                
                Section(header: Text("AWS CloudFront Configuration")) {
                    TextField("CloudFront Distribution ID", text: Binding(
                        get: { blog.awsCloudFrontDistId ?? "" },
                        set: { blog.awsCloudFrontDistId = $0.isEmpty ? nil : $0 }
                    ))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                }
                
                Section(
                    header: Text("AWS Cognito Identity Pool"), 
                    footer: Text("The Identity Pool provides secure, temporary AWS credentials with limited permissions to access your S3 bucket and CloudFront distribution.")
                ) {
                    TextField("Cognito Identity Pool ID", text: Binding(
                        get: { blog.awsIdentityPoolId ?? "" },
                        set: { blog.awsIdentityPoolId = $0.isEmpty ? nil : $0 }
                    ))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    
                    Link("How to create an Identity Pool", destination: URL(string: "https://docs.aws.amazon.com/cognito/latest/developerguide/tutorial-create-identity-pool.html")!)
                }
                
                Section(footer: Text("You can remove AWS configuration at any time.")) {
                    Button(action: {
                        // Clear AWS configuration
                        blog.awsRegion = nil
                        blog.awsS3Bucket = nil
                        blog.awsCloudFrontDistId = nil
                        blog.awsIdentityPoolId = nil
                    }) {
                        Text("Clear AWS Configuration")
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Setup Guide")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("1. Create an S3 bucket configured for static website hosting")
                        
                        Text("2. Create a CloudFront distribution pointing to your S3 bucket")
                        
                        Text("3. Create a Cognito Identity Pool with unauthenticated access")
                        
                        Text("4. Add IAM permissions to the Identity Pool's unauthenticated role that allow:")
                            .padding(.bottom, 5)
                        
                        Text("• s3:PutObject for your bucket")
                            .padding(.leading)
                        
                        Text("• cloudfront:CreateInvalidation for your distribution")
                            .padding(.leading)
                    }
                    .font(.callout)
                }
            }
            .navigationTitle("AWS Configuration")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    dismiss()
                }
            )
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Blog.self, configurations: config)
    let blog = Blog(name: "Sample Blog", url: "https://example.com")
    
    return BlogAwsConfigView(blog: blog)
        .modelContainer(container)
}