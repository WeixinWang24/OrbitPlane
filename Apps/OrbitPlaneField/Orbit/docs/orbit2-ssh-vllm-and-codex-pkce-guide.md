# Orbit2 SSH vLLM 与 OpenAI Codex PKCE 连接指南

本文面向 Orbit iOS / Swift 开发 Agent，抽象当前 Orbit2 的两条 provider 连接链路：

- 远程 vLLM 通过 SSH tunnel 暴露为本地 OpenAI-compatible endpoint。
- OpenAI Codex Auth 通过 OAuth PKCE bootstrap 获取、保存、刷新 bearer credential。

目标不是逐字移植 Orbit2 的 Python 文件，而是复用其通信边界、配置优先级、安全约束和 Swift 实现步骤。

## 1. 总体原则

Orbit2 将 provider 视为协议适配器：

```text
Runtime / Session
  -> Provider config resolver
  -> Provider adapter
  -> Remote model endpoint
  -> Normalized provider plan
```

Provider 只负责：

- 读取已解析的连接配置。
- 构造 HTTP / SSE 请求。
- 解析 provider response。
- 提取文本、tool calls、usage、finish reason。
- 把错误归一化为项目内部结果。

Provider 不负责：

- 创建或维护 SSH tunnel。
- 管理 OAuth 浏览器交互 UI 之外的 session。
- 执行工具调用。
- 保存 transcript。
- 处理多轮 continuation。

Swift 项目中建议保留同样边界：

```text
Orbit iOS App
  -> Runtime / ChatViewModel
  -> AgentProvider protocol
    -> OpenAICompatibleProvider    vLLM path
    -> CodexProvider               Codex SSE path, optional
  -> ProviderPlan
```

## 2. 当前 Orbit2 vLLM 链路

Orbit2 的 vLLM backend 实际使用 OpenAI-compatible Chat Completions。

当前链路：

```text
Orbit2 CLI
  -> _build_backend("vllm")
  -> resolve_vllm_provider_settings(runtime_root)
  -> OpenAICompatibleBackend(OpenAICompatibleConfig)
  -> openai.OpenAI(base_url=..., api_key=...)
  -> client.chat.completions.create(...)
  -> SSH tunnel exposed localhost endpoint
  -> remote vLLM server
```

对应 Orbit2 代码位置：

- `src/config/runtime.py`
  - `resolve_vllm_provider_settings`
  - `_normalize_openai_base_url`
- `src/core/providers/openai_compatible.py`
  - `OpenAICompatibleConfig`
  - `OpenAICompatibleBackend`
- `src/operation/cli/harness.py`
  - `_build_backend("vllm", ...)`

## 3. SSH Tunnel 连接细节

Orbit2 当前不在 provider 内部创建 SSH tunnel。Tunnel 是 operator/runtime 外部步骤。

典型远程 vLLM 情况：

```text
remote vLLM server
  listens on remote host:8080
  exposes /v1/chat/completions

local Mac
  opens SSH tunnel
  listens on localhost:8000

Orbit2 / Swift provider
  calls http://localhost:8000/v1/chat/completions
```

示例命令：

```bash
ssh -N -L 8000:<remote-vllm-host>:8080 <ssh-target>
```

如果远端 vLLM 服务就在 SSH 目标机器的本机 8080：

```bash
ssh -N -L 8000:127.0.0.1:8080 <ssh-target>
```

如果需要跳板机：

```bash
ssh -N -J <jump-user>@<jump-host> -L 8000:<remote-vllm-host>:8080 <ssh-target>
```

连接测试：

```bash
curl http://localhost:8000/v1/models
```

或：

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "<served-model-name>",
    "messages": [{"role": "user", "content": "ping"}],
    "max_tokens": 32
  }'
```

## 4. iOS / Simulator / 真机差异

Swift 项目要特别注意 `localhost` 的含义。

### macOS CLI 或 Orbit2 Python

`http://localhost:8000/v1` 指向当前 Mac，直接匹配 SSH tunnel。

### iOS Simulator

通常可以从 Simulator app 访问 Mac 上的 localhost 服务。开发期可先使用：

```text
http://localhost:8000/v1
```

如果访问失败，改用 Mac 的局域网地址：

```text
http://<mac-lan-ip>:8000/v1
```

### iPhone 真机

真机的 `localhost` 是手机本机，不是 Mac。

真机调试有三种方案：

1. 在 Mac 上让 tunnel 监听局域网地址，然后 iPhone 访问 Mac LAN IP。
2. 使用开发代理服务，由代理服务连接本机 tunnel。
3. 在 app 或 companion process 中实现单独的安全 tunnel 管理。

开发期可用：

```bash
ssh -N -L 0.0.0.0:8000:<remote-vllm-host>:8080 <ssh-target>
```

然后 iPhone 使用：

```text
http://<mac-lan-ip>:8000/v1
```

注意：`0.0.0.0` 会把本地端口暴露给局域网。只应在可信网络中短时间使用，最好加防火墙、Basic Auth 或反向代理认证。

## 5. vLLM 配置优先级

Orbit2 的配置优先级：

```text
.runtime/agent_runtime.toml explicit value
  -> env var named by config
  -> default env var
  -> default value
```

Swift 可以简化为：

```text
in-app debug settings
  -> process env / scheme env
  -> bundled development config
  -> defaults
```

建议配置项：

```swift
struct VLLMProviderSettings {
    var model: String
    var baseURL: URL
    var apiKey: String?
    var basicAuthUsername: String?
    var basicAuthPassword: String?
    var maxTokens: Int
}
```

Orbit2 默认变量：

```text
ORBIT2_PROVIDER_MODEL
ORBIT2_VLLM_BASE_URL
ORBIT2_VLLM_API_KEY
ORBIT2_VLLM_USERNAME
ORBIT2_VLLM_PASSWORD
```

Orbit2 默认 base URL：

```text
http://localhost:8000/v1
```

## 6. Base URL 规范化

Orbit2 会把误传的完整 endpoint 裁成 base URL。

输入：

```text
http://localhost:8000/v1/chat/completions
```

规范化后：

```text
http://localhost:8000/v1
```

Swift 实现：

```swift
func normalizeOpenAIBaseURL(_ raw: String) -> String {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    while value.hasSuffix("/") {
        value.removeLast()
    }

    let suffix = "/chat/completions"
    if value.hasSuffix(suffix) {
        value.removeLast(suffix.count)
    }
    return value
}
```

构造请求时再追加：

```text
/chat/completions
```

## 7. vLLM Chat Completions 请求

请求：

```text
POST {baseURL}/chat/completions
Content-Type: application/json
```

如果 vLLM gateway 要求 API key：

```text
Authorization: Bearer <apiKey>
```

如果 gateway 使用 Basic Auth：

```text
Authorization: Basic base64(username:password)
```

请求体：

```json
{
  "model": "<served-model-name>",
  "max_tokens": 1024,
  "messages": [
    {"role": "system", "content": "You are helpful."},
    {"role": "user", "content": "Hello"}
  ],
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "read_file",
        "description": "Read a file.",
        "parameters": {
          "type": "object",
          "properties": {
            "path": {"type": "string"}
          },
          "required": ["path"]
        }
      }
    }
  ]
}
```

只在存在工具时发送 `tools`。

## 8. vLLM 响应归一化

Orbit2 将 Chat Completions response 归一化为 `ExecutionPlan`。Swift 中建议使用同类结构：

```swift
struct ProviderPlan {
    var sourceBackend: String
    var label: String
    var finalText: String?
    var model: String
    var toolRequests: [ToolRequest]
    var metadata: [String: JSONValue]
}
```

映射规则：

```text
choices[0].message.content       -> finalText
choices[0].message.tool_calls    -> toolRequests
response.model                   -> model
choices[0].finish_reason         -> metadata.finish_reason
response.usage                   -> metadata.usage
```

Tool call arguments 是 JSON 字符串。解析失败时不要崩溃，保留原始字符串：

```json
{
  "_raw_arguments": "...",
  "_parse_error": true
}
```

Provider 只返回 tool request；真正执行工具的是 runtime。

## 9. OpenAI Codex Auth：PKCE 角色与常量

Orbit2 的 Codex Auth bootstrap 在 `src/core/providers/codex_oauth.py`。

重要澄清：这里的 PKCE 是 **OAuth 授权码流程**，不是普通 OpenAI API key 验证方式。

Swift Agent 不应把 PKCE 接到这些路径上：

```text
https://api.openai.com/v1/...
Authorization: Bearer <OPENAI_API_KEY>
```

也不应把 `code_verifier`、`code_challenge`、`state` 当成 API 请求参数传给 Chat Completions、Responses API 或 vLLM endpoint。

Orbit2 当前实现中，PKCE 只服务于下面这条 Codex OAuth bootstrap 链路：

```text
Browser / ASWebAuthenticationSession
  -> https://auth.openai.com/oauth/authorize?...code_challenge=...
  -> callback with ?code=...&state=...
  -> POST https://auth.openai.com/oauth/token
       grant_type=authorization_code
       code_verifier=...
  -> access_token + refresh_token
  -> CodexBackend Authorization: Bearer <access_token>
  -> https://chatgpt.com/backend-api/codex/responses
```

也就是说：

- vLLM path 使用 OpenAI-compatible Chat Completions，可以用 API key、Basic Auth，或无 auth 的本地 tunnel；不使用 PKCE。
- 普通 OpenAI API path 通常使用 API key 或项目自己的 OAuth 代理策略；不等于 Orbit2 这里的 Codex PKCE。
- Codex path 使用 OAuth PKCE 得到 bearer access token，再访问 `chatgpt.com/backend-api/codex/responses`。

### 当前产品行为上的重要风险

如果 Swift Agent 打开 PKCE URL 后被引导到 OpenAI API / Platform 界面，这不一定表示“所有 OAuth 已取消”，但说明该入口很可能不是可供任意 iOS app 稳定接入的通用 OAuth 产品面。

OpenAI 官方当前对 Codex CLI 的说明是“Sign in with ChatGPT”会把 ChatGPT identity 连接到 API account，并在本地保存 credentials；该流程还会自动创建 Codex CLI 使用的 API key，而不是要求用户手动复制 API key。换句话说，面向用户可见的 Codex 登录产品语义已经明显偏向：

```text
ChatGPT sign-in
  -> link / select API account or org
  -> Codex CLI local credentials
  -> auto-generated Codex CLI API key / usable local auth
```

这和 Orbit2 当前 `codex_oauth.py` 中复刻的低层 OAuth PKCE 常量并不完全等价。Orbit2 的 PKCE 实现可以作为研究 Codex CLI 授权链路的参考，但 Swift iOS app 不应假设：

- `auth.openai.com/oauth/authorize` + 这个 Codex client id 是公开稳定的第三方 OAuth 接入方式。
- iOS app 可以随意替换 redirect URI。
- 该 flow 一定会返回适合直接调用 `chatgpt.com/backend-api/codex/responses` 的长期 bearer credential。

对 Orbit iOS 更稳的实现路线：

1. vLLM：继续使用 SSH tunnel + OpenAI-compatible endpoint。
2. OpenAI API：使用 API key 或后端代理，不使用 Codex PKCE。
3. Codex CLI 兼容：开发期可以从 Codex CLI 本地 auth / generated key 导入，但要把它标记为 developer-only bridge。
4. Codex OAuth PKCE：保留为实验/研究路径，不作为 iOS app 的主认证方案，除非确认 OpenAI 提供正式支持的 app client、redirect URI 和授权说明。

关键常量：

```text
Authorize URL: https://auth.openai.com/oauth/authorize
Token URL:     https://auth.openai.com/oauth/token
Client ID:     app_EMoamEEZ73f0CkXaXp7hrann
Redirect URI:  http://localhost:1455/auth/callback
Scope:         openid profile email offline_access
```

Credential 默认保存到：

```text
<runtime-root>/.runtime/openai_oauth_credentials.json
```

Orbit2 保存格式：

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "expires_at_epoch_ms": 1770000000000,
  "account_email": "user@example.com"
}
```

文件权限会设为 `0600`。Swift/iOS 中不应写普通 JSON 文件保存 token，应该使用 Keychain。

## 10. PKCE Step 1：生成 Login URL

Orbit2 生成：

- `state`
- `code_verifier`
- `code_challenge`
- `authorize_url`

PKCE verifier：

```text
random URL-safe string
```

PKCE challenge：

```text
base64url_no_padding(SHA256(code_verifier))
```

Authorize query 参数：

```text
response_type=code
client_id=app_EMoamEEZ73f0CkXaXp7hrann
redirect_uri=http://localhost:1455/auth/callback
scope=openid profile email offline_access
state=<random-state>
code_challenge=<S256 challenge>
code_challenge_method=S256
originator=orbit2
```

Swift 侧建议：

```swift
struct PKCESession {
    var state: String
    var codeVerifier: String
    var codeChallenge: String
    var authorizeURL: URL
}
```

用 `ASWebAuthenticationSession` 打开 `authorizeURL`。回调 URL 需要根据 iOS app 的能力调整。Orbit2 使用 localhost callback，是 CLI/browser bootstrap 形态；iOS app 更适合使用 custom URL scheme 或 universal link。如果复用 OpenAI Codex 的既有 localhost redirect，需要由本地 companion process 接 callback，然后把 callback URL 交给 app/runtime。

## 11. PKCE Step 2：解析 Callback

Orbit2 接受三类输入：

1. 完整 callback URL：

```text
http://localhost:1455/auth/callback?code=<code>&state=<state>
```

2. query string：

```text
?code=<code>&state=<state>
```

3. raw authorization code：

```text
code-value-only
```

解析规则：

- 如果 callback 包含 `error`，失败并展示 `error_description`。
- 必须能拿到 `code`。
- 如果传入 expected state，且 callback 里有 state，则必须匹配。

Swift 侧应严格校验 `state`，防止 CSRF / session confusion。

## 12. PKCE Step 3：Exchange Authorization Code

Orbit2 用 form POST 到 token endpoint：

```text
POST https://auth.openai.com/oauth/token
Content-Type: application/x-www-form-urlencoded
```

表单：

```text
grant_type=authorization_code
client_id=app_EMoamEEZ73f0CkXaXp7hrann
redirect_uri=http://localhost:1455/auth/callback
code=<authorization-code>
code_verifier=<code-verifier>
state=<state, optional>
```

成功响应至少需要：

```json
{
  "access_token": "...",
  "refresh_token": "...",
  "expires_in": 3600
}
```

Orbit2 会转换为：

```text
expires_at_epoch_ms = now + expires_in
```

如果响应包含：

```text
expires_at
```

则使用该 epoch seconds 转为 milliseconds。

Swift 侧保存：

- `access_token`
- `refresh_token`
- `expires_at_epoch_ms`
- optional account email

保存位置：Keychain。

## 13. PKCE Step 4：Refresh Token

Orbit2 refresh 请求：

```text
POST https://auth.openai.com/oauth/token
Content-Type: application/x-www-form-urlencoded
```

表单：

```text
grant_type=refresh_token
client_id=app_EMoamEEZ73f0CkXaXp7hrann
refresh_token=<stored-refresh-token>
scope=openid profile email offline_access
```

响应可能不返回新的 refresh token。Orbit2 的规则是：

```text
如果 response.refresh_token 存在，使用新的；
否则保留旧 refresh_token。
```

Swift 侧也应如此，避免 refresh 后丢失长期凭据。

## 14. Codex CLI Auth Import

Orbit2 还支持从 Codex CLI auth 文件导入：

```text
~/.codex/auth.json
```

它支持两种形态：

```json
{
  "tokens": {
    "access_token": "...",
    "refresh_token": "..."
  }
}
```

或：

```json
{
  "access_token": "...",
  "refresh_token": "..."
}
```

Orbit2 会尝试从 JWT `exp` 字段推断 `expires_at_epoch_ms`；如果没有可解析 expiry，则默认约 1 小时。

iOS 项目一般不应直接读取 `~/.codex/auth.json`。但开发工具或 Mac companion app 可以提供 import 功能，再通过安全通道写入 iOS Keychain 或开发配置。

### Orbit2 当前可用 Credential 文件

当前 Orbit2 本地 runtime 中已经保存了一份可用 Codex credential：

```text
/Volumes/2TB/Dev/Orbit2/.runtime/openai_oauth_credentials.json
```

该文件是当前自用链路的最直接 credential 来源。Swift Agent 应将它视为 **developer-only / personal-use import source**，而不是公开登录入口。

文件结构与 Orbit2 `OAuthCredential` 一致：

```json
{
  "access_token": "<secret>",
  "refresh_token": "<secret>",
  "expires_at_epoch_ms": 1770000000000,
  "account_email": "optional@example.com"
}
```

导入原则：

- 不要把 token 内容写进源码、Markdown、commit、日志或 Xcode project settings。
- 不要让 iOS app 在运行时直接依赖 Mac 文件路径；该路径只供开发者手动导入。
- 手动复制 JSON 后，iOS app 应立即写入 Keychain。
- Keychain 中保存 `access_token`、`refresh_token`、`expires_at_epoch_ms` 和可选 `account_email`。
- UI 文案应使用 `Import Local Codex Credential`，不要写成 `Sign in with OpenAI` 或正式 OAuth 登录。
- 导入后可删除剪贴板内容，避免 token 长时间留在 pasteboard。

推荐手动导入流程：

```text
1. 在 Mac 上确认 Orbit2 credential 文件存在：
   /Volumes/2TB/Dev/Orbit2/.runtime/openai_oauth_credentials.json

2. 开发者手动打开该 JSON 文件，仅在本机可信环境中复制内容。

3. 在 Orbit iOS debug/import UI 中粘贴 JSON。

4. Swift 解析 JSON 为 CodexCredential。

5. Swift 校验：
   - access_token 非空
   - refresh_token 非空
   - expires_at_epoch_ms > now，或立即尝试 refresh

6. Swift 将 credential 写入 Keychain。

7. 后续 CodexProvider 只从 Keychain 读取，不再依赖手动粘贴内容。
```

Swift 侧建议模型：

```swift
struct CodexCredential: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAtEpochMs: Int64
    var accountEmail: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAtEpochMs = "expires_at_epoch_ms"
        case accountEmail = "account_email"
    }
}
```

该导入路径的定位：

```text
status: developer-only / personal-use bridge
source: /Volumes/2TB/Dev/Orbit2/.runtime/openai_oauth_credentials.json
storage: iOS Keychain after import
refresh: best-effort via Codex OAuth refresh-token flow
fallback: re-import from Orbit2 credential file when refresh fails
```

## 15. Codex Provider 使用 Credential

Orbit2 的 Codex provider 在启动时加载 credential：

```text
<runtime-root>/.runtime/openai_oauth_credentials.json
```

加载规则：

- 文件不存在：失败。
- access token 为空：失败。
- `expires_at_epoch_ms <= now`：失败，要求 refresh。

请求 Codex endpoint：

```text
POST https://chatgpt.com/backend-api/codex/responses
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: text/event-stream
```

payload：

```json
{
  "model": "<model>",
  "store": false,
  "stream": true,
  "input": [],
  "instructions": "...",
  "tools": [],
  "text": {
    "verbosity": "medium"
  }
}
```

## 16. Codex SSE 事件处理

Orbit2 的 SSE transport 只处理以 `data:` 开头的行：

```text
data: {...json...}
data: [DONE]
```

处理规则：

- 空行忽略。
- 非 `data:` 行忽略。
- `[DONE]` 结束流。
- JSON decode 失败的 data 行忽略。
- HTTP error 转成 transport error。
- URL connection error 转成 connection error。

Codex provider 归一化事件：

```text
response.output_text.delta       -> streaming partial text
response.output_text.done        -> completed text source
response.output_item.done        -> authoritative function_call / message item
response.completed               -> fallback final response and output items
response.done                    -> fallback final response and output items
response.incomplete              -> status / usage / model metadata
error                            -> normalized error plan
```

Tool call 提取：

```text
item.type == "function_call"
call_id   -> tool_call_id
id        -> provider_item_id
name      -> tool_name
arguments -> JSON parsed arguments
```

Swift 侧如果实现 Codex SSE provider，也应输出与 vLLM provider 相同的 `ProviderPlan`。

## 17. Swift 实现建议

### Provider protocol

```swift
protocol AgentProvider {
    var backendName: String { get }

    func plan(
        from request: TurnRequest,
        onPartialText: ((String) -> Void)?
    ) async -> ProviderPlan
}
```

### vLLM provider

```swift
final class OpenAICompatibleProvider: AgentProvider {
    let settings: VLLMProviderSettings
    let session: URLSession

    var backendName: String { "openai-compatible" }

    func plan(
        from request: TurnRequest,
        onPartialText: ((String) -> Void)? = nil
    ) async -> ProviderPlan {
        // Build {baseURL}/chat/completions.
        // Encode model, max_tokens, messages, tools.
        // Send JSON request.
        // Decode Chat Completions response.
        // Normalize text/tool calls/errors.
    }
}
```

### Codex auth manager

```swift
final class CodexAuthManager {
    func createPKCESession() throws -> PKCESession
    func exchange(callbackURL: URL, session: PKCESession) async throws -> CodexCredential
    func refresh(_ credential: CodexCredential) async throws -> CodexCredential
    func loadCredential() throws -> CodexCredential
    func saveCredential(_ credential: CodexCredential) throws
}
```

Use Keychain for `CodexCredential`.

### Codex provider

```swift
final class CodexProvider: AgentProvider {
    let credentialStore: CodexCredentialStore
    let session: URLSession

    var backendName: String { "openai-codex" }

    func plan(
        from request: TurnRequest,
        onPartialText: ((String) -> Void)?
    ) async -> ProviderPlan {
        // Load non-expired access token.
        // POST /codex/responses.
        // Parse SSE data lines.
        // Normalize text/tool calls/errors.
    }
}
```

## 18. Recommended Implementation Order

1. Define shared `TurnRequest`, `ProviderMessage`, `ToolDefinition`, `ToolRequest`, `ProviderPlan`.
2. Implement `OpenAICompatibleProvider` for vLLM.
3. Add base URL normalization and Basic Auth header support.
4. Test against a local fake OpenAI-compatible server.
5. Test against SSH tunnel to remote vLLM.
6. Add iOS Simulator connection docs and UI settings for base URL/model.
7. Implement PKCE helper: verifier, challenge, state, authorize URL.
8. Implement callback parsing and state validation.
9. Implement authorization-code exchange.
10. Implement developer-only manual import from Orbit2 credential JSON.
11. Store imported credential in Keychain.
12. Implement refresh flow, preserving old refresh token when response omits a new one.
13. Optionally implement Codex SSE provider behind the same `AgentProvider` protocol.

## 19. Acceptance Checklist

vLLM path is correct when:

- The Swift provider calls an OpenAI-compatible `/v1/chat/completions` endpoint.
- SSH tunnel is created outside provider code.
- `localhost` behavior is handled separately for Mac, Simulator, and iPhone.
- Base URL normalization prevents duplicate `/chat/completions`.
- Tool-call arguments parse failures are recoverable.
- Provider returns normalized plans and does not execute tools.

PKCE path is correct when:

- It is implemented as OAuth authorization-code-with-PKCE, not as OpenAI API key validation.
- `code_verifier`, `code_challenge`, and `state` are used only with `auth.openai.com/oauth/authorize` and `auth.openai.com/oauth/token`.
- vLLM Chat Completions and ordinary OpenAI API requests never receive PKCE fields.
- `code_verifier` is random and URL-safe.
- `code_challenge` is S256 base64url without padding.
- `state` is generated and validated.
- Exchange uses `authorization_code` grant with `code_verifier`.
- Refresh uses `refresh_token` grant.
- Missing new refresh token preserves the old refresh token.
- Tokens are stored in Keychain, not plain files.
- Codex provider refuses expired access tokens or refreshes before use.

## 20. One-Line Summary

For vLLM, expose the remote model through an external SSH tunnel and treat it as a local OpenAI-compatible endpoint; for Codex, bootstrap OAuth credentials with PKCE, store them securely, refresh them conservatively, and keep both backends behind the same Swift provider protocol that returns normalized provider plans.
