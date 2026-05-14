# Telegram Bot Setup Guide for Orbit

## 1. Create a Telegram Bot

1. Open Telegram and search for **@BotFather**
2. Send `/newbot`
3. Follow the prompts:
   - Enter a **name** for your bot (e.g., `Orbit Agent`)
   - Enter a **username** ending in `bot` (e.g., `orbit_agent_bot`)
4. BotFather will reply with your **Bot API Token**, which looks like:
   ```
   7123456789:AAH1bGciOiJSUzI1NiIsInR5...
   ```
5. **Copy this token** — you'll paste it into Orbit's Settings.

## 2. Create a Group and Add the Bot

1. Create a new Telegram group (or use an existing one)
2. Add your bot as a member of the group
3. Send at least one message in the group

## 3. Get the Group Chat ID

Option A — Use the bot API directly:

1. Send a message in the group that mentions your bot
2. Open this URL in your browser (replace `<TOKEN>` with your bot token):
   ```
   https://api.telegram.org/bot<TOKEN>/getUpdates
   ```
3. Look for the `"chat"` object in the response. The `"id"` field is your Chat ID.
   - Group chat IDs are **negative numbers** (e.g., `-1001234567890`)

Option B — Use @RawDataBot:

1. Add `@RawDataBot` to your group temporarily
2. Send any message — it will reply with the chat details including the Chat ID
3. Remove `@RawDataBot` after getting the ID

## 4. Configure in Orbit

1. Open Orbit → Settings → scroll to **TELEGRAM BRIDGE**
2. Paste your **Bot Token** into the token field
3. Paste your **Chat ID** into the chat ID field
4. Tap the **Connect** toggle

The bot token is stored in your device's Keychain — it never leaves your device
and is not included in iCloud backups.

## 5. Bot Privacy Settings (Important)

By default, bots in groups only receive messages that:
- Start with `/` (commands)
- Mention the bot directly (`@your_bot_name`)

To receive **all messages** in the group:

1. Go back to **@BotFather**
2. Send `/mybots` → select your bot → **Bot Settings** → **Group Privacy**
3. Set to **Disabled** (this enables the bot to see all messages)

## Security Notes

- Your bot token grants full control of the bot — treat it like a password
- Orbit stores the token in the iOS Keychain (encrypted, hardware-backed)
- The token is never sent to any server other than `api.telegram.org`
- If compromised, revoke it immediately via BotFather: `/revoke`
