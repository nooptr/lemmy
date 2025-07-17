# Claude Bridge Fetch Interception and Abort Signal Analysis

## Current Fetch Interception Implementation

### Location of Global Fetch "Swizzling"
The global fetch interception occurs in `/Users/badlogic/workspaces/lemmy/todos/worktrees/2025-07-17-01-25-35-fix-fetch-abort-signal-handling/apps/claude-bridge/src/interceptor.ts` at **lines 104-116**:

```typescript
public instrumentFetch(): void {
    if (!global.fetch || (global.fetch as any).__claudeBridgeInstrumented) return;

    const originalFetch = global.fetch;
    global.fetch = async (input: Parameters<typeof fetch>[0], init: RequestInit = {}): Promise<Response> => {
        const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url;
        if (!isAnthropicAPI(url)) return originalFetch(input, init);
        return this.handleAnthropicRequest(originalFetch, input, init);
    };

    (global.fetch as any).__claudeBridgeInstrumented = true;
    this.logger.log("Claude Bridge interceptor initialized");
}
```

### How Current Interception Works

1. **URL Filtering**: Only Anthropic API calls (`api.anthropic.com/v1/messages`) are intercepted via `isAnthropicAPI()` check
2. **Request Processing**: Intercepted requests go through `handleAnthropicRequest()` method (lines 118-169)
3. **Transformation Pipeline**: 
   - Parse Anthropic request format
   - Transform to lemmy Context format
   - Route to alternative provider (OpenAI, Google, etc.)
   - Convert response back to Anthropic SSE format

### Current Request Flow

```
Claude Code → global.fetch() → interceptor.ts:instrumentFetch() 
    → handleAnthropicRequest() → callProvider() → lemmy client → Provider API
    → createAnthropicSSE() → Response back to Claude Code
```

## Missing Abort Signal Handling

### The Problem
The current implementation **completely ignores** the `RequestInit.signal` parameter that is passed to the intercepted fetch calls. This leads to:

1. **Concurrency Bugs**: If Claude Code tries to cancel a request (e.g., user cancels operation), the underlying provider call continues
2. **Resource Leaks**: Ongoing requests to alternative providers continue consuming resources
3. **Race Conditions**: Completed "cancelled" requests may still arrive and interfere with new requests

### Current Lack of Abort Signal Evaluation

In the current code:

**interceptor.ts lines 108-111:**
```typescript
global.fetch = async (input: Parameters<typeof fetch>[0], init: RequestInit = {}): Promise<Response> => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url;
    if (!isAnthropicAPI(url)) return originalFetch(input, init);
    return this.handleAnthropicRequest(originalFetch, input, init);
};
```

**interceptor.ts lines 118-122:**
```typescript
private async handleAnthropicRequest(
    originalFetch: typeof fetch,
    input: Parameters<typeof fetch>[0],
    init: RequestInit,
): Promise<Response> {
```

The `init.signal` property is passed through but **never checked or propagated** to the provider calls.

## Specific Code Locations That Need Changes

### 1. `/apps/claude-bridge/src/interceptor.ts`

**Line 108** - Add abort signal validation:
```typescript
global.fetch = async (input: Parameters<typeof fetch>[0], init: RequestInit = {}): Promise<Response> => {
    // CHECK: if (init.signal?.aborted) throw new DOMException('AbortError', 'AbortError');
    const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url;
    if (!isAnthropicAPI(url)) return originalFetch(input, init);
    return this.handleAnthropicRequest(originalFetch, input, init);
};
```

**Lines 118-169** - `handleAnthropicRequest()` method needs:
- Abort signal checking before transformation
- Abort signal propagation to provider calls
- Cleanup of pending requests on abort

**Lines 194-266** - `callProvider()` method needs:
- Abort signal passed to lemmy client calls
- Proper error handling for aborted requests

### 2. `/apps/claude-bridge/src/utils/provider.ts`

The `createProviderClient()` and provider-specific calls may need abort signal support, depending on whether the lemmy clients support abort signals.

### 3. Provider Call Integration Points

**interceptor.ts line 244:**
```typescript
const askResult: AskResult = await this.clientInfo.client.ask(askInput, { context, ...askOptions });
```

This call needs abort signal propagation if the lemmy client supports it.

## Missing Abort Signal Features

1. **Initial Abort Check**: No check if signal is already aborted before starting work
2. **Abort Event Listeners**: No listeners for abort events during processing
3. **Cleanup on Abort**: No cleanup of `pendingRequests` map when requests are aborted
4. **Provider Call Abort**: No abort signal propagation to underlying provider HTTP calls
5. **Race Condition Prevention**: No mechanisms to prevent completed aborted requests from interfering

## Recommended Implementation Strategy

1. **Add abort signal validation** at fetch interception point
2. **Propagate abort signals** through the transformation pipeline
3. **Add abort event listeners** during async operations
4. **Implement proper cleanup** in pendingRequests tracking
5. **Handle abort errors** consistently with standard fetch behavior
6. **Test abort scenarios** to ensure proper cancellation behavior

The key insight is that the current architecture transforms one async operation (Anthropic API call) into another async operation (alternative provider call), but completely loses the abort signal context in this transformation, creating potential for resource leaks and race conditions when Claude Code attempts to cancel operations.

## Claude-Bridge Codebase Analysis: Error Handling, Async Operations, and Abort Signal Support

Based on my exploration of the claude-bridge codebase, here's what I found regarding existing patterns and the specific abort signal handling issue:

### 1. **Existing Error Handling Patterns**

**Error handling in the interceptor (`interceptor.ts`):**
- Uses try-catch blocks consistently in async methods like `handleAnthropicRequest()` and `callProvider()`
- Has a dedicated `logProviderError()` method that logs comprehensive error details including type, constructor, message, stack, cause, code, and HTTP status
- Uses a `handleError()` method in lemmy clients that converts various error types to `ModelError` format
- Implements proper cleanup in the interceptor with `pendingRequests` tracking and cleanup on exit

**Error handling in lemmy clients:**
- All clients (Anthropic, OpenAI, Google) have consistent `handleError()` methods that map HTTP status codes to error types (`auth`, `rate_limit`, `invalid_request`, `api_error`)
- Error objects include `retryable` flags and `retryAfter` information for rate limits
- Uses discriminated union types for `AskResult` with success/error variants

### 2. **Async Operations Patterns**

**Current async patterns:**
- Heavy use of async/await throughout the codebase
- Streaming is handled using `AsyncIterable` patterns (e.g., `for await (const event of stream)`)
- Promise-based architecture with proper error propagation
- The interceptor uses `Map<string, any>` to track `pendingRequests` but doesn't handle cancellation

### 3. **Lemmy Client Abort Signal Support**

**Critical Finding: NO abort signal support in any lemmy clients**
- Anthropic client: `ask()` method has no abort signal parameter or handling
- OpenAI client: `ask()` method has no abort signal parameter or handling  
- Google client: Similar pattern, no abort signal support
- The underlying SDK calls (e.g., `this.anthropic.messages.create()`) don't receive abort signals
- **This means even if the claude-bridge interceptor handled abort signals, the underlying lemmy clients wouldn't respect them**

### 4. **Current Abort Signal Issue in Claude-Bridge**

**The specific problem in `interceptor.ts` line 108-116:**
```typescript
global.fetch = async (input: Parameters<typeof fetch>[0], init: RequestInit = {}): Promise<Response> => {
    const url = typeof input === "string" ? input : input instanceof URL ? input.toString() : input.url;
    if (!isAnthropicAPI(url)) return originalFetch(input, init);
    return this.handleAnthropicRequest(originalFetch, input, init);
};
```

**Problems identified:**
1. The `init.signal` (AbortSignal) is completely ignored
2. When `handleAnthropicRequest()` calls `this.callProvider()`, any abort signal is lost
3. The lemmy client calls don't support abort signals anyway
4. If the original request is aborted, the bridge continues processing, leading to orphaned requests

### 5. **Testing Patterns**

**Existing test infrastructure:**
- Custom test framework in `test/framework.ts` with `TestRunner`, `TestSuite`, and `Test` interfaces
- Unit tests in `test/unit.ts` covering transforms, utilities, and basic interceptor creation
- CLI integration tests with `CLITestRunner` that can validate log output
- Mock/stub capabilities for testing provider clients
- No existing tests for abort signal handling or cancellation scenarios

### 6. **Recommendations for Fix**

**Priority 1: Claude-Bridge Interceptor Fix**
1. Check for `init.signal` in the fetch interceptor
2. Create an `AbortController` that combines the original signal with internal cancellation
3. Pass abort signals through to the lemmy client calls
4. Handle `AbortError` properly and clean up pending requests

**Priority 2: Lemmy Client Enhancement**
1. Add abort signal support to the `AskOptions` type
2. Update all client `ask()` methods to accept and respect abort signals
3. Pass abort signals to underlying SDK calls (Anthropic, OpenAI, Google SDKs all support this)

**Priority 3: Testing**
1. Add unit tests for abort signal handling in the interceptor
2. Add integration tests that simulate request cancellation
3. Test cleanup of pending requests on abort

### 7. **Files That Need Changes**

**Immediate fixes needed:**
- `/apps/claude-bridge/src/interceptor.ts` - Add abort signal handling
- `/packages/lemmy/src/types.ts` - Add abort signal to AskOptions
- `/packages/lemmy/src/clients/*.ts` - Update all clients to support abort signals

**Test files to create/update:**
- `/apps/claude-bridge/test/unit.ts` - Add abort signal tests
- New test file for abort signal integration tests

The abort signal issue is a legitimate concurrency bug that could cause resource leaks and unexpected behavior when users cancel requests. The fix requires changes at both the claude-bridge interceptor level and the underlying lemmy client level.