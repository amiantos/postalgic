![Postalgic](/postalgic-logo.png?raw=true)

Postalgic is a self-hosted static CMS for creating and publishing blogs. Write from the web interface, generate static HTML, and publish to your own hosting (S3, SFTP, Git).

Build anywhere. Publish anywhere.

# Features

- [x] Create, manage, and update blogs from the self-hosted web interface
- [x] Generate static HTML/CSS websites automatically
- [x] Templating system using [Mustache](https://mustache.github.io)
- [x] Publish to a variety of static hosting services
  - [x] AWS S3 with CloudFront
  - [x] Any SFTP Server
  - [x] Any Git Repository

# Getting Started

Run Postalgic on your own server with Docker:

```bash
curl -O https://raw.githubusercontent.com/amiantos/postalgic/main/docker-compose.yml
docker compose up -d
```

Access the app at http://localhost:8010

## Authentication

Postalgic protects the admin UI with a passkey. The first time you visit the
app you'll be guided through a one-time setup wizard to register a passkey
with your password manager (1Password, Apple Keychain, Bitwarden, etc.).

WebAuthn requires HTTPS — most browsers won't allow passkey ceremonies on
plain HTTP from a non-localhost address. If you're serving Postalgic over
plain HTTP from another machine, uncomment `BASIC_AUTH_USERNAME` /
`BASIC_AUTH_PASSWORD` in `docker-compose.yml` to fall back to HTTP basic auth.

**Lost your passkey?** With Postalgic stopped, delete the row from
`auth_credentials` in `data/postalgic.db`:

```bash
sqlite3 data/postalgic.db "DELETE FROM auth_credentials;"
```

Restarting will return you to the setup wizard.

## Development

```bash
npm run install:all
npm run dev
```

This installs dependencies for both the server and Vue client, then starts both in development mode with hot reloading.

# iOS App

Looking for the iOS app? It has moved to its own repository: [postalgic-ios](https://github.com/amiantos/postalgic-ios)

The iOS app is also available on the [App Store](https://apps.apple.com/us/app/postalgic-pocket-blogger/id6446164693).

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
