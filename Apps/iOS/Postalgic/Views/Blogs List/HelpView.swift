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
            ScrollView(.vertical) {
                VStack {
                    HelpTextView {
                        Text("What is Postalgic?").font(.title3).bold().padding(.bottom, 6)
                        Text("Postalgic is an all-in-one blogging client for your pocket. It allows you to create blogs, write posts, and then automatically generate the HTML for the site, and upload it to a host of your choosing. It's micro-blogging, or full blown blogging, fully decentralized in the way it should have always been for the past 25 years.")
                    }
                    HelpTextView {
                        Text("Open Source").font(.title3).bold().padding(.bottom, 6)
                        Text("Postalgic is open source, which means that if there's something you don't like about it, *you* have the power to change it. You can download the source code, make it better, and share your improvements with others. Neat, huh? At least, I think so. You can find [the source code on GitHub](https://github.com/amiantos/postalgic).")
                    }
                    HelpTextView {
                        Text("Who built this?").font(.title3).bold().padding(.bottom, 6)
                        Text("Postalgic was built by Brad Root, also known as Amiantos. He's built a number of great iOS apps, like...")
                    }
                    HelpTextView {
                        Text("Need more help?").font(.title3).bold().padding(.bottom, 6)
                        Text("It's easy to get in touch with me, if you have more questions: you can email me directly at bradroot@me.com, don't be shy!")
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("Done") }
                }
            }
            .navigationTitle("Postalgic Help")
            .navigationBarTitleDisplayMode(.inline)
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
        .padding(20)
        .background(.fill)
        .clipShape(RoundedRectangle(cornerRadius: 25.0))
        .padding([.leading, .trailing, .bottom])
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
