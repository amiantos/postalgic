![Postalgic](/postalgic-logo.png?raw=true)

Postalgic is a static CMS for creating and publishing blogs. Write from iOS or the self-hosted web app, generate static HTML, and publish to your own hosting (S3, SFTP, Git).

Build anywhere. Publish anywhere.

# Features

- [x] Create, manage, and update blogs from iOS or the self-hosted web interface
- [x] Generate static HTML/CSS websites automatically
- [x] Templating system using [Mustache](https://mustache.github.io)
- [x] Publish to a variety of static hosting services
  - [x] AWS S3 with CloudFront
  - [x] Any SFTP Server
  - [x] Any Git Repository

# Self-Hosted

Run Postalgic on your own server with Docker:

```bash
curl -O https://raw.githubusercontent.com/amiantos/postalgic/main/docker-compose.yml
docker compose up -d
```

Access the app at http://localhost:8010

See [Self-Hosted](Self-Hosted/) for more options including development setup.

# iOS

The iOS app is available on the [App Store](https://apps.apple.com/us/app/postalgic-pocket-blogger/id6446164693) or you can build it yourself from [iOS](iOS/).

# Example Blogs
- https://dev.postalgic.app
- https://ihavebeenfloated.org
- https://staires.org
- https://jozef.postalgic.app
- https://bigbountycards.com

# Credits
- Postalgic is created and maintained by [Brad Root](https://github.com/amiantos)

# License
- The app and backend code are licensed under the terms of the [Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/2.0/)
- Postalgic name and branding is &copy; 2026 Brad Root
