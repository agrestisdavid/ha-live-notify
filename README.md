# HA Live Notify

Live Activities for Home Assistant on iPhone – self-hosted, no cloud service required.

## Features

- Timer entities as Live Activities on Lock Screen & Dynamic Island
- Push notifications even when the app is closed
- Customizable icons and colors per timer
- Real-time animated progress bar
- Fully self-hosted via HA Add-on

## Requirements

- iPhone with iOS 18+
- Home Assistant installation (with Supervisor/Add-on support)
- Apple Developer Account (free or $99/year)
- Mac with Xcode 26+

## Setup Guide

### 1. Apple Developer Account

1. Go to [developer.apple.com](https://developer.apple.com) and sign in
2. Create an account if you don't have one yet
3. Accept the Apple Developer License Agreement
4. Note your **Team ID** (under Account → Membership)

### 2. Create APNs Key

1. Go to [developer.apple.com/account/resources/authkeys](https://developer.apple.com/account/resources/authkeys/list)
2. Click the **+** icon to create a new key
3. Enter a name (e.g. "HA Live Notify")
4. Enable **Apple Push Notifications service (APNs)**
5. Click **Continue** then **Register**
6. **Download the .p8 file** (this can only be done once!)
7. Note the **Key ID** (10-character ID, e.g. `ABC1234DEF`)

### 3. Install HA Add-on

1. Open Home Assistant → **Settings** → **Add-ons** → **Add-on Store**
2. Click **⋮** (three dots top right) → **Repositories**
3. Add: `https://github.com/agrestisdavid/ha-live-notify-addon`
4. Search for **"HA Live Notify Relay"** and install it
5. Go to the add-on **Configuration** and enter:
   - `apns_key_id`: Your Key ID from step 2
   - `apns_team_id`: Your Team ID from step 1
   - `apns_bundle_id`: `ios.ha-live-notify` (default)
   - `apns_use_sandbox`: `true` (for development, `false` for production builds)
6. Start the add-on

### 4. Upload AuthKey.p8

The APNs key file must be copied to the add-on config directory:

**Option A: Via Samba/SMB Share**
1. Install the "Samba share" add-on if not already present
2. Connect to the share
3. Copy `AuthKey.p8` to `addon_configs/ha-live-notify-relay/AuthKey.p8`

**Option B: Via SSH**
1. Connect to your HA host via SSH
2. Copy the file:
   ```bash
   cp AuthKey.p8 /addon_configs/ha-live-notify-relay/AuthKey.p8
   ```

3. Restart the add-on

### 5. Build and Install the App

1. Clone this repository:
   ```bash
   git clone https://github.com/agrestisdavid/ha-live-notify.git
   ```
2. Open `ha-live-notify.xcodeproj` in Xcode
3. Select your Apple Developer Team under **Signing & Capabilities** for **both targets**:
   - `ha-live-notify` (the app)
   - `ha-live-notify-widgets` (the widget extension)
4. Connect your iPhone via USB or Wi-Fi
5. Select your iPhone as the build target
6. Click **Run** (or Cmd+R)

### 6. Configure the App

1. **Home Assistant Connection:**
   - Open the app → Tap "Connect"
   - Enter your Home Assistant URL (e.g. `http://homeassistant.local:8123`)
   - Create a Long-Lived Access Token in HA: **Profile** → **Security** → **Long-Lived Access Tokens** → **Create Token**
   - Paste the token into the app

2. **Push Relay Connection:**
   - Go to **Settings** → **Push Relay**
   - Enter the Relay URL (e.g. `http://homeassistant.local:8765`)
   - Find the **API Key** in the add-on logs (or in `/addon_configs/ha-live-notify-relay/api_key.txt`)
   - Test the connection with the "Test Connection" button

3. **Select Entities:**
   - Go to **Settings** → **Entities**
   - Select the timer entities you want to display as Live Activities

### 7. Create HA Automation

Timer entities need to be created in Home Assistant and started by automations. The add-on receives updates via a REST endpoint.

Create an automation that notifies the relay on timer changes:

```yaml
alias: Live Notify - Timer Update
description: Sends timer updates to the push relay
triggers:
  - trigger: state
    entity_id:
      - timer.washing_machine
      - timer.dryer
      - timer.dishwasher
conditions: []
actions:
  - action: rest_command.live_notify_update
    data:
      entity_id: "{{ trigger.entity_id }}"
      state: "{{ trigger.to_state.state }}"
      end_time: "{{ trigger.to_state.attributes.finishes_at | default('') }}"
      total_duration: "{{ trigger.to_state.attributes.duration | default('') }}"
      device_name: "{{ trigger.to_state.attributes.friendly_name | default(trigger.entity_id) }}"
mode: parallel
max: 10
```

### 8. Set Up rest_command

Add the following to your `configuration.yaml`:

```yaml
rest_command:
  live_notify_update:
    url: "http://localhost:8765/update"
    method: POST
    headers:
      Authorization: "Bearer YOUR_API_KEY"
      Content-Type: "application/json"
    payload: >
      {
        "entity_id": "{{ entity_id }}",
        "state": "{{ state }}",
        "end_time": "{{ end_time }}",
        "total_duration": "{{ total_duration }}",
        "device_name": "{{ device_name }}"
      }
    content_type: "application/json"
```

Replace `YOUR_API_KEY` with the API key from the add-on logs.

Then reload the configuration: **Developer Tools** → **YAML** → **REST Commands**.

## Architecture

```
HA Timer Entity
     │
     ▼
HA Automation (state trigger)
     │
     ▼
rest_command.live_notify_update
     │
     ▼
Push Relay Add-on (localhost:8765)
     │
     ▼
Apple Push Notification service (APNs)
     │
     ▼
iPhone → Live Activity (Lock Screen + Dynamic Island)
```

## License

MIT
