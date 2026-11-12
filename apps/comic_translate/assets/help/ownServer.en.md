
# Prompt for configuring Own Server in Comic Translate Screen

Copy this document into an AI chat with the provider's documentation. Remove real keys, tokens, private messages and images from the examples. Enter the API key in the app's API key field.

## Task for the assistant

Help me configure Settings → Translator → Own Server in Comic Translate Screen using the provider's documentation. Ask whether I need text chat and translation, the model catalog, key information, OCR with images, or OCR and translation in one request. Ask short questions when essential details are missing. Never request a real key. Use documented URLs, model IDs, authorization headers and response fields.

I can provide the service name and documentation, the desired model ID and its image capabilities, and redacted HTTP status codes and JSON bodies. If I have already tried the connection, I can provide redacted test chat logs or the local response check.

Give the exact profile values and tell me which fields can keep their defaults. For each of the three operations below, say whether to keep the built-in request, use a full HTTP template, or skip the operation. Where a template is needed, give separate blocks for the HTTP request and the JSON response rules. Finish with the smallest possible test and explain which field to change based on its result. If the protocol falls outside the editor's capabilities, explain the difference.

## Profile fields

1. Create a named profile. Enter the documented base URL with scheme and port. The app appends each operation's path. For example, `http://localhost:1234/v1` and `chat/completions` become `http://localhost:1234/v1/chat/completions`. Include `/v1` only where the provider specifies it. Enter the base URL without the operation path.
2. Save the key in the API key field and select the active key. A local server can use an empty key if it needs no authentication. The app checks that a key is saved before using a cloud connection. A header with `{{api_key}}` receives the active key and is omitted when the key is empty.
3. Enter the exact model ID manually or load the catalog. The model may be empty if the server selects a default when `model` is omitted. For OCR, choose an image-capable model explicitly under Settings → Recognition. OCR can use the same profile and a different model.
4. Keep Profile settings for a compatible API. Compatibility settings allow relative paths and additional JSON fields. A `null` override omits a field. `model`, `messages` and `stream` are reserved in compatibility mode. Change the token limit field only if the provider requires `max_tokens`, `max_completion_tokens` or no field.
5. If a method, authorization header, body or response differs, enable the full HTTP request for the relevant operation in a named template. The profile supplies the address, model and key. Edits to a shared template apply to every profile using it.

## 1. Chat, translation and network OCR

The built-in operation is `POST chat/completions`. Test chat sends a conversation. Translation and OCR add the app's instructions and frame data. The compatible image format is a `content` array with `type: "image_url"` items whose `image_url.url` is a base64 data URL. Use a model that accepts this format for OCR and image chat.

The full HTTP request takes this form.

```http
POST chat/completions
Authorization: Bearer {{api_key}}
Content-Type: application/json

{
  "model": {{model}},
  "messages": {{messages}},
  "temperature": {{temperature}},
  "max_completion_tokens": {{token_limit}}
}
```

Leave a blank line before the body. Available JSON variables are `{{model}}`, `{{messages}}`, `{{temperature}}`, `{{max_completion_tokens}}`, `{{max_tokens}}`, `{{token_limit}}` and `{{payload}}`. Use each as a whole, unquoted value. `{{payload}}` inserts the standard body. Omit the token limit field or change its name according to the documentation. A property with a missing variable is omitted. Set any extra body parameters directly in the full request.

For a one-message test, `{{messages}}` may expand to `[{"role":"user","content":"Reply OK"}]`. With OCR, the content may contain text and one or more images. Keep `{{messages}}` dynamic so the request includes the user's text and the app's instructions and frames.

Use these rules for the built-in response.

```json
{
  "text": "choices[0].message.content",
  "finish": "choices[0].finish_reason",
  "usage": "usage",
  "error": "error.message"
}
```

`text` is required and must resolve to a nonempty string or a list of objects with `text` fields. `finish`, `usage` and `error` are optional. The following example uses HTTP status 200.

```json
{"choices":[{"message":{"content":"OK"},"finish_reason":"stop"}]}
```

The extracted text has its own format. Translation must preserve the exact frame keys from the request, for example `{"block_0":"Hello","block_1":"Goodbye"}`. Keys can differ when translating several pages at once. OCR expects lines such as `[01-001] Hello`. Combined OCR and translation expects `[01-001] Bonjour --> Hello`. Keep the IDs from the request. Extra prompt instructions may change style or terminology while retaining this format. Check the extracted text separately in the Prompt editor.

## 2. Model catalog

The built-in request is `GET models`. Use manual model entry if the provider has no catalog.

```http
GET models
Authorization: Bearer {{api_key}}
```

```json
{
  "items": "data",
  "id": "id",
  "name": "name",
  "vision": "architecture.input_modalities",
  "error": "error.message"
}
```

`items` must point to an array. `id` is required and relative to each item. `name` and `vision` are optional item paths. `vision` accepts `true` or an array containing `"image"`. Keep this example path only if it matches the provider's JSON.

```json
{"data":[{"id":"demo/vision","name":"Demo Vision","architecture":{"input_modalities":["text","image"]}}]}
```

## 3. Key information

There is no universal balance or quota path. Configure this operation only if the provider documents one. Use the compatibility GET path and field mapping or a full HTTP request. The following endpoint and fields are illustrative.

```http
GET usage/key
Authorization: Bearer {{api_key}}
```

```json
{
  "fields": {
    "Remaining": "data.balance",
    "Unit": "data.unit"
  },
  "error": "error.message"
}
```

`fields` is required. Each label maps to a string, number or boolean in the response. Avoid fields containing credentials. Use this sample body for a local check.

```json
{"data":{"balance":12.5,"unit":"credits"}}
```

## SSE responses

The stream must end with `data: [DONE]` or the signal specified by `done_data` or `done_event`. If the connection closes earlier, the chat keeps the received text and marks the response incomplete.

In Translator settings, turn on “Stream response (SSE)” for OpenRouter or an OpenAI-compatible connection. Own Server saves this setting per profile. When a full Chat and translation HTTP request is active, its rules determine the response format.

Set `"stream": {{stream}}` in the full chat request or use `{{payload}}`. In SSE mode the stream variable is true, and the app adds `Accept: text/event-stream` if omitted. Use the paths documented by the server. An OpenAI-compatible stream usually uses these rules.

```json
{
  "format": "sse",
  "text": "choices[0].delta.content",
  "finish": "choices[0].finish_reason",
  "usage": "usage",
  "error": "error.message"
}
```

Paste events with their blank lines in Check pasted SSE.

```text
data: {"choices":[{"delta":{"content":"Hel"}}]}

data: {"choices":[{"delta":{"content":"lo"}}]}

data: [DONE]

```

The app joins the text chunks in order. The default marker is `data: [DONE]`. EOF between events can also end the stream. Use `done_data` or `done_event` for a different marker. The chat displays incoming text. Translation and OCR match frames after the full response.

## Uploading files with multipart/form-data

Use `Content-Type: multipart/form-data` without a boundary. Write the form as a JSON object with the documented field names. Set the file field to `{{files}}` as its whole value. For example, with an illustrative `process-file` endpoint:

```http
POST process-file
Authorization: Bearer {{api_key}}
Content-Type: multipart/form-data

{
  "model": {{model}},
  "prompt": {{prompt}},
  "file": {{files}}
}
```

`{{prompt}}` is the text of the last user message. Use `{{messages}}` when the endpoint needs conversation history. With `{{files}}`, images are sent as binary parts and their base64 data is omitted from the conversation. Multiple files use separate parts with the same field name. Catalog and key requests can use multipart text fields when their API requires it.

With a file field configured, the HTTP test and chat can attach files up to 10 MB. Network OCR uses the generated frame images. Confirm the destination before the chat sends attachments.

## Verification and limits

- Put the method and relative path on the first line. The editor supports `GET`, `HEAD`, `POST`, `PUT`, `PATCH`, `DELETE` and `OPTIONS`. Use the documented method. Non-secret query parameters are allowed in full requests. Keep the request on the profile's host and credentials in headers. For example, use `X-API-Key: {{api_key}}` only when the provider expects that header.
- Response paths support dots, numeric indexes and `$` for the root. Success defaults to HTTP 2xx. Use an optional `statuses` array only when the documented success codes differ. Successful responses must be JSON.
- Preview the request first. Use Check pasted JSON with an example body and HTTP status, then send a short test after confirmation. For OCR, start with a harmless sample image and then check a reply with two frame IDs in the Prompt editor.
- For 401, check the active key and authorization header. For 403, check access and provider restrictions. For 404, verify the base URL, operation path and model ID. For 429, check rate limits. For 2xx with a parse error, compare the rules with the actual JSON and the frame output format.
- SSE applies to chat and extracts fields from JSON in each event. The editor handles one HTTP request at a time. For multi-step authentication or arbitrary transformations of `{{messages}}`, check for a compatible API.
