//
//  HelpView.swift
//  Postalgic
//
//  Created by Brad Root on 4/24/25.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading) {
                        Text("What is Postalgic?").font(.title3).bold().padding([.top, .bottom], 8)
                        Text("""
                        Postalgic is an all-in-one blogging client for your pocket. It allows you to create blogs, write posts, and then automatically generate the HTML for the site, and upload it to a host of your choosing. It's micro-blogging, fully decentralized in the way it should have always been for the past 25 years.
                        
                        To learn more about Postalgic and how to use its features, visit the [Postalgic Help Center](https://postalgic.app/help).
                        """).padding(.bottom, 8)
                    }
                }
                Section {
                    VStack(alignment: .leading) {
                        Text("Open Source").font(.title3).bold().padding([.top, .bottom], 8)
                        Text("Postalgic is open source, which means that if there's something you don't like about it, *you* have the power to change it. You can download the source code, make it better, and share your improvements with others. Neat, huh? At least, I think so. You can find [the source code on GitHub](https://github.com/amiantos/postalgic).").padding(.bottom, 8)
                    }
                }
                Section {
                    VStack(alignment: .leading) {
                        Text("Who built this?").font(.title3).bold().padding([.top, .bottom], 8)
                        Text("Postalgic was built by Brad Root, also known as Amiantos. He's built a number of great iOS apps, you can view them [on the App Store](https://apps.apple.com/us/developer/brad-root/id1158641227).").padding(.bottom, 8)
                    }
                }
                Section {
                    VStack(alignment: .leading) {
                        Text("Need more help?").font(.title3).bold().padding([.top, .bottom], 8)
                        Text("It's easy to get in touch with me, if you have more questions: you can email me directly at bradroot@me.com, don't be shy!").padding(.bottom, 8)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Done") }
                }
            }
            .navigationTitle("About")
        }
    }
}

#Preview {
    NavigationStack {
        HelpView()
    }
}

struct HelpTextView<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading) {
            content()
        }
    }
}
