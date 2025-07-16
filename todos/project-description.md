# Project: Lemmy

A TypeScript monorepo ecosystem for building AI applications with unified multi-provider LLM support, terminal UI components, and development tools.

## Features

- Unified interface for Anthropic Claude, OpenAI, and Google Gemini
- Manual tool execution with full control and interception
- Rich terminal UI framework with differential rendering
- Development tools for monitoring AI interactions
- Bridge to use alternative LLMs with Claude-specific tools
- MCP (Model Context Protocol) integration

## Tech Stack

- TypeScript (primary language)
- Node.js ≥ 18.0.0
- npm workspaces (monorepo management)
- Vitest (testing framework)
- tsup (bundler)
- Zod (schema validation)
- Tailwind CSS (claude-trace frontend)
- Swift (macOS native components)

## Structure

- `/packages/lemmy` - Core LLM wrapper library
- `/packages/lemmy-tui` - Terminal UI components
- `/packages/lemmy-tools` - Built-in and custom tools
- `/packages/lemmy-cli-args` - CLI argument parsing
- `/apps/` - Example applications (chat, bridge, trace, etc.)

## Architecture

- Provider abstraction with ChatClient interface
- Zod schema-based tool definitions
- Streaming support with thinking/reasoning blocks
- Context management for conversation state
- Type-safe throughout (avoiding `any`)

## Commands

- Build: `npm run build`
- Test: `npm run test`
- Lint: `npm run typecheck`
- Dev/Run: `npm run dev`

## Testing

- Framework: Vitest
- Test files: `test/**/*.test.ts` pattern
- Create tests using describe/it/expect
- Run with `npm test` (watch) or `npm run test:run` (once)

## Editor

- Open folder: `code`
