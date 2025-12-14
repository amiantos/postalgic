# Postalgic Self-Hosted

A self-hosted web version of the Postalgic static blog generator. Create and manage your blog through a web interface, then generate and download your static site.

## Features

- **Blog Management**: Create and manage multiple blogs
- **Post Editor**: Write posts in Markdown with live preview
- **Categories & Tags**: Organize your content
- **Sidebar Customization**: Add text blocks and link lists
- **File Uploads**: Upload images and other static files
- **Theme Customization**: Customize colors and styling
- **Static Site Generation**: Generate a complete static site
- **ZIP Download**: Download your site as a ZIP for deployment

## Quick Start

### Using Docker (Recommended)

```bash
# Clone and navigate to the directory
cd Apps/Self-Hosted

# Build and run with Docker Compose
docker compose up -d

# Access the app at http://localhost:8010
```

### Development Mode

```bash
# Install dependencies
npm run install:all

# Start development servers (backend + frontend)
npm run dev

# Backend runs on http://localhost:8010
# Frontend runs on http://localhost:5188 (with hot reload)
```

### Manual Production Build

```bash
# Install dependencies
npm run install:all

# Build the Vue frontend
npm run client:build

# Start the production server
NODE_ENV=production npm start
```

## Project Structure

```
Apps/Self-Hosted/
├── server/                 # Express backend
│   ├── routes/            # API routes
│   ├── services/          # Business logic (site generation, etc.)
│   └── utils/             # Utilities (storage, helpers)
├── vue_client/            # Vue 3 frontend
│   ├── src/
│   │   ├── api/          # API client
│   │   ├── components/   # Vue components
│   │   ├── stores/       # Pinia stores
│   │   └── views/        # Page components
│   └── ...
├── data/                  # User data (created at runtime)
├── Dockerfile
├── docker-compose.yml
└── package.json
```

## Data Storage

All data is stored as JSON files in the `data/` directory:

```
data/
├── blogs/
│   └── {blogId}/
│       ├── blog.json           # Blog settings
│       ├── posts/              # Post files
│       ├── categories/         # Category files
│       ├── tags/               # Tag files
│       ├── sidebar/            # Sidebar objects
│       ├── static-files/       # File metadata
│       ├── uploads/            # Uploaded files
│       └── published-files.json
├── themes/                     # Custom themes
└── generated/                  # Generated sites (for preview)
```

## API Endpoints

### Blogs
- `GET /api/blogs` - List all blogs
- `POST /api/blogs` - Create a blog
- `GET /api/blogs/:id` - Get a blog
- `PUT /api/blogs/:id` - Update a blog
- `DELETE /api/blogs/:id` - Delete a blog

### Posts
- `GET /api/blogs/:blogId/posts` - List posts
- `POST /api/blogs/:blogId/posts` - Create a post
- `GET /api/blogs/:blogId/posts/:id` - Get a post
- `PUT /api/blogs/:blogId/posts/:id` - Update a post
- `DELETE /api/blogs/:blogId/posts/:id` - Delete a post

### Categories, Tags, Sidebar
- Similar CRUD endpoints under `/api/blogs/:blogId/`

### Publishing
- `POST /api/blogs/:blogId/publish/generate` - Generate site
- `POST /api/blogs/:blogId/publish/download` - Download as ZIP
- `GET /api/blogs/:blogId/publish/status` - Get publish status

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8010` | Server port |
| `NODE_ENV` | `development` | Environment mode |

## License

MIT
