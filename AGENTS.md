# AI Agent Development Guidelines

This document provides instructions for AI agents (LLMs, coding assistants) working on this repository. Follow these guidelines to maintain consistency and code quality.

## Project Overview

This is a full-stack RAG (Retrieval-Augmented Generation) application with infrastructure as code. The repository contains:
- **Terraform**: Infrastructure provisioning and deployment automation
- **Python Backend**: RAG service integrating LLM and vector database
- **TypeScript Frontend**: Web interface for user interactions

## Repository Structure

```
project-root/
├── terraform/          # Infrastructure as Code
│   ├── environments/   # Environment-specific configs (dev/staging/prod)
│   └── modules/        # Reusable Terraform modules
├── backend/            # Python RAG application
│   ├── app/            # Main application package
│   │   ├── api/        # API routes and endpoints
│   │   ├── services/   # Business logic (LLM, vector DB, RAG)
│   │   ├── models/     # Data models and schemas
│   │   └── utils/      # Helper functions
│   └── tests/          # Test suite
├── frontend/           # TypeScript web application
│   ├── src/
│   │   ├── components/ # React components
│   │   ├── pages/      # Page-level components
│   │   ├── services/   # API client code
│   │   ├── hooks/      # Custom React hooks
│   │   ├── types/      # TypeScript definitions
│   │   └── utils/      # Utility functions
│   └── public/         # Static assets
├── scripts/            # Deployment and utility scripts
└── docs/               # Documentation
```

## General Principles

### File Organization
- **Keep related code together**: Group by feature/domain, not by file type
- **Separate concerns**: API, business logic, and data access should be distinct
- **DRY principle**: Extract reusable code into utilities or shared modules
- **Single Responsibility**: Each file/module should have one clear purpose

### Naming Conventions
- **Terraform**: Use snake_case for resources, variables, and outputs
- **Python**: Follow PEP 8 (snake_case for functions/variables, PascalCase for classes)
- **TypeScript**: Use camelCase for functions/variables, PascalCase for components/classes
- **Files**: Match the primary export (e.g., `UserProfile.tsx` for UserProfile component)

### Code Style
- **Terraform**: Use consistent formatting with `terraform fmt`
- **Python**: Follow PEP 8, use type hints, max line length 88 (Black formatter)
- **TypeScript**: Use ESLint/Prettier, prefer functional components, use TypeScript strict mode
- **Comments**: Write self-documenting code; use comments for "why" not "what"

## Terraform Guidelines

### Structure
- Place environment-specific configurations in `terraform/environments/{env}/`
- Create reusable modules in `terraform/modules/` for shared infrastructure
- Always include `variables.tf`, `outputs.tf`, and `main.tf` for each module
- Use `terraform.tfvars.example` to document required variables

### Best Practices
- **State Management**: Use remote state (S3, Terraform Cloud) configured in `backend.tf`
- **Variables**: Define all variables with descriptions and types
- **Outputs**: Export values needed by other modules or external systems
- **Naming**: Use descriptive names with prefixes (e.g., `prod-app-server`)
- **Secrets**: NEVER hardcode secrets; use variables and secret management services
- **Modules**: Version your modules and use specific versions in environments

### Common Commands
```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
terraform destroy
```

## Python Backend Guidelines

### Structure
- **API Layer** (`app/api/`): FastAPI/Flask routes, request validation, response formatting
- **Service Layer** (`app/services/`): Business logic, LLM calls, vector DB operations
- **Models** (`app/models/`): Pydantic schemas, data validation
- **Utils** (`app/utils/`): Helper functions, embeddings, text processing

### Best Practices
- **Type Hints**: Always use type hints for function parameters and return values
- **Async/Await**: Use async functions for I/O operations (API calls, DB queries)
- **Error Handling**: Use try-except blocks, return meaningful error messages
- **Logging**: Use Python's logging module, not print statements
- **Environment Variables**: Use python-dotenv or similar, never hardcode configs
- **Dependencies**: Keep `requirements.txt` updated and pinned to specific versions

### LLM Integration
- Abstract LLM calls into service classes (`llm_service.py`)
- Implement retry logic with exponential backoff
- Handle token limits and context windows
- Cache embeddings when possible
- Log all LLM interactions for debugging

### Vector Database
- Use service classes for vector DB operations (`vector_db_service.py`)
- Implement connection pooling
- Handle indexing and search separately
- Include metadata with embeddings
- Implement proper error handling for connection failures

### Testing
- Write unit tests for services and utilities
- Use pytest fixtures for common setup
- Mock external API calls (LLM, vector DB)
- Aim for >80% code coverage
- Include integration tests for critical paths

### Common Commands
```bash
cd backend
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt
pip install -r requirements-dev.txt
pytest
python -m app.main  # Run the application
```

## Frontend Guidelines

### Structure
- **Components** (`src/components/`): Reusable UI components, organized by feature
- **Pages** (`src/pages/`): Top-level route components
- **Services** (`src/services/`): API client functions
- **Hooks** (`src/hooks/`): Custom React hooks for shared logic
- **Types** (`src/types/`): TypeScript interfaces and types
- **Utils** (`src/utils/`): Pure utility functions

### Best Practices
- **TypeScript**: Use strict mode, avoid `any`, define interfaces for all data structures
- **Components**: Prefer functional components with hooks
- **State Management**: Use React hooks (useState, useContext) or add Redux if needed
- **API Calls**: Centralize in service layer, use async/await
- **Error Handling**: Display user-friendly error messages, log errors
- **Accessibility**: Use semantic HTML, ARIA labels, keyboard navigation
- **Performance**: Lazy load routes, memoize expensive operations

### RAG UI Patterns
- Implement streaming responses for LLM outputs
- Show loading states during API calls
- Display source citations from vector DB results
- Provide chat history and conversation management
- Include feedback mechanisms (thumbs up/down)

### Testing
- Write unit tests for utilities and hooks
- Use React Testing Library for component tests
- Mock API calls in tests
- Test user interactions and edge cases

### Common Commands
```bash
cd frontend
npm install
npm run dev        # Start development server
npm run build      # Production build
npm run test       # Run tests
npm run lint       # Lint code
```

## Configuration Management

### Environment Variables
- **NEVER** commit `.env` files with real secrets
- Always provide `.env.example` with dummy values
- Document all required environment variables in README
- Use different variable prefixes for different environments

### Required Variables
```bash
# Backend
DATABASE_URL=
VECTOR_DB_URL=
LLM_API_KEY=
LLM_MODEL=
EMBEDDING_MODEL=

# Frontend
VITE_API_URL=
VITE_ENVIRONMENT=

# Terraform
AWS_REGION=
AWS_ACCOUNT_ID=
```

## Development Workflow

### Making Changes
1. **Understand the context**: Read related code before making changes
2. **Follow patterns**: Match existing code style and architecture
3. **Test locally**: Run tests and verify functionality
4. **Update docs**: Update README or relevant documentation
5. **Check dependencies**: Ensure no breaking changes

### Adding Features
1. **Backend**: Add service → Add API route → Add tests → Update OpenAPI docs
2. **Frontend**: Add types → Add service function → Add component → Add tests
3. **Infrastructure**: Create/update module → Test in dev → Apply to staging → Production

### Debugging
- **Backend**: Check logs, use debugger, verify environment variables
- **Frontend**: Use browser dev tools, check network tab, verify API responses
- **Terraform**: Use `terraform plan` to preview changes, check state file

## Docker and Deployment

### Docker
- Each service (backend, frontend) has its own Dockerfile
- Use multi-stage builds for smaller images
- Don't include development dependencies in production images
- Use `.dockerignore` to exclude unnecessary files

### Common Docker Commands
```bash
# Build
docker build -t app-backend ./backend
docker build -t app-frontend ./frontend

# Run with docker-compose
docker-compose up -d
docker-compose logs -f
docker-compose down
```

### Deployment
- Use Terraform to provision infrastructure
- Deploy backend as containerized service (ECS, Cloud Run, etc.)
- Deploy frontend to CDN/static hosting (S3 + CloudFront, Vercel, etc.)
- Use CI/CD pipelines for automated deployments
- Always test in staging before production

## Common Pitfalls to Avoid

### Terraform
- ❌ Hardcoding values instead of using variables
- ❌ Not using remote state
- ❌ Applying changes directly to production without testing
- ❌ Not tagging resources appropriately

### Backend
- ❌ Blocking I/O in async functions
- ❌ Not handling API rate limits
- ❌ Storing secrets in code
- ❌ Missing error handling for external services
- ❌ Not validating user input

### Frontend
- ❌ Not handling loading and error states
- ❌ Exposing API keys in client code
- ❌ Not optimizing bundle size
- ❌ Ignoring accessibility
- ❌ Not handling API errors gracefully

## Security Considerations

- **API Keys**: Store in environment variables, use secret management services
- **Authentication**: Implement proper auth for API endpoints
- **Input Validation**: Validate and sanitize all user inputs
- **CORS**: Configure appropriate CORS policies
- **Rate Limiting**: Implement rate limiting on API endpoints
- **Dependencies**: Regularly update and audit dependencies
- **Secrets in Logs**: Never log sensitive information

## Documentation Requirements

When making changes:
- Update README.md if adding new features or changing setup
- Add docstrings to Python functions
- Add JSDoc comments to complex TypeScript functions
- Update API documentation when changing endpoints
- Document environment variables in `.env.example`
- Update architecture docs in `docs/` for significant changes

## Questions and Clarifications

If you need clarification:
1. Check existing code for similar patterns
2. Review documentation in `docs/`
3. Check README files in each directory
4. Look for examples in tests
5. Ask the developer for guidance on architectural decisions

## Version Control

- Write clear, descriptive commit messages
- Keep commits focused and atomic
- Reference issue numbers when applicable
- Don't commit sensitive data or large binary files

---

**Remember**: The goal is to write clean, maintainable, and secure code that follows established patterns in this repository. When in doubt, prioritize clarity and consistency over cleverness.