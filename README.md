# HA Live Notify

Live Activities für Home Assistant auf dem iPhone – selbst gehostet, kein Cloud-Dienst nötig.

## Features

- Timer-Entities als Live Activities auf Lock Screen & Dynamic Island
- Push-Benachrichtigungen auch wenn die App geschlossen ist
- Anpassbare Icons und Farben pro Timer
- Fortschrittsbalken mit Echtzeit-Animation
- Komplett self-hosted über HA Add-on

## Voraussetzungen

- iPhone mit iOS 18+
- Home Assistant Installation (mit Supervisor/Add-on Support)
- Apple Developer Account (kostenlos oder $99/Jahr)
- Mac mit Xcode 26+

## Setup-Anleitung

### 1. Apple Developer Account

1. Gehe zu [developer.apple.com](https://developer.apple.com) und melde dich an
2. Erstelle einen Account falls noch nicht vorhanden
3. Akzeptiere die Apple Developer License Agreement
4. Notiere dir deine **Team ID** (unter Account → Membership)

### 2. APNs Key erstellen

1. Gehe zu [developer.apple.com/account/resources/authkeys](https://developer.apple.com/account/resources/authkeys/list)
2. Klicke auf das **+** Symbol um einen neuen Key zu erstellen
3. Gib einen Namen ein (z.B. "HA Live Notify")
4. Aktiviere **Apple Push Notifications service (APNs)**
5. Klicke auf **Continue** und dann **Register**
6. **Lade die .p8 Datei herunter** (dies ist nur einmal möglich!)
7. Notiere dir die **Key ID** (10-stellige ID, z.B. `ABC1234DEF`)

### 3. HA Add-on installieren

1. Öffne Home Assistant → **Settings** → **Add-ons** → **Add-on Store**
2. Klicke auf **⋮** (drei Punkte oben rechts) → **Repositories**
3. Füge hinzu: `https://github.com/agrestisdavid/ha-live-notify-addon`
4. Suche nach **"HA Live Notify Relay"** und installiere es
5. Gehe in die **Konfiguration** des Add-ons und trage ein:
   - `apns_key_id`: Deine Key ID aus Schritt 2
   - `apns_team_id`: Deine Team ID aus Schritt 1
   - `apns_bundle_id`: `ios.ha-live-notify` (Standard)
   - `apns_use_sandbox`: `true` (für Entwicklung, `false` für Production-Builds)
6. Starte das Add-on

### 4. AuthKey.p8 hochladen

Die APNs Key-Datei muss in den Add-on Konfigurationsordner kopiert werden:

**Option A: Via Samba/SMB Share**
1. Installiere das "Samba share" Add-on falls nicht vorhanden
2. Verbinde dich mit dem Share
3. Kopiere `AuthKey.p8` nach `addon_configs/ha-live-notify-relay/AuthKey.p8`

**Option B: Via SSH**
1. Verbinde dich per SSH mit deinem HA Host
2. Kopiere die Datei:
   ```bash
   cp AuthKey.p8 /addon_configs/ha-live-notify-relay/AuthKey.p8
   ```

3. Starte das Add-on neu

### 5. App bauen und installieren

1. Klone dieses Repository:
   ```bash
   git clone https://github.com/agrestisdavid/ha-live-notify.git
   ```
2. Öffne `ha-live-notify.xcodeproj` in Xcode
3. Wähle dein Apple Developer Team unter **Signing & Capabilities** für **beide Targets**:
   - `ha-live-notify` (die App)
   - `ha-live-notify-widgets` (die Widget Extension)
4. Verbinde dein iPhone per USB oder WLAN
5. Wähle dein iPhone als Build-Ziel
6. Klicke auf **Run** (oder Cmd+R)

### 6. App konfigurieren

1. **Home Assistant Verbindung:**
   - Öffne die App → Tippe auf "Verbinden"
   - Gib deine Home Assistant URL ein (z.B. `http://homeassistant.local:8123`)
   - Erstelle einen Long-Lived Access Token in HA: **Profil** → **Sicherheit** → **Long-Lived Access Tokens** → **Token erstellen**
   - Füge den Token in die App ein

2. **Push Relay Verbindung:**
   - Gehe zu **Einstellungen** → **Push Relay**
   - Gib die Relay URL ein (z.B. `http://homeassistant.local:8765`)
   - Den **API Key** findest du in den Add-on Logs (oder in der Datei `/addon_configs/ha-live-notify-relay/api_key.txt`)
   - Teste die Verbindung mit dem "Verbindung testen" Button

3. **Entities auswählen:**
   - Gehe zu **Einstellungen** → **Entities**
   - Wähle die Timer-Entities aus, die als Live Activities angezeigt werden sollen

### 7. HA Automation erstellen

Timer-Entities müssen in Home Assistant erstellt und von anderen Automations gestartet werden. Das Add-on selbst empfängt Updates über einen REST-Endpunkt.

Erstelle eine Automation, die bei Timer-Änderungen das Relay benachrichtigt:

```yaml
alias: Live Notify - Timer Update
description: Sendet Timer-Updates an das Push Relay
triggers:
  - trigger: state
    entity_id:
      - timer.waschmaschine
      - timer.trockner
      - timer.spuelmaschine
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

### 8. rest_command einrichten

Füge folgenden Block in deine `configuration.yaml` ein:

```yaml
rest_command:
  live_notify_update:
    url: "http://localhost:8765/update"
    method: POST
    headers:
      Authorization: "Bearer DEIN_API_KEY"
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

Ersetze `DEIN_API_KEY` mit dem API Key aus den Add-on Logs.

Lade danach die Konfiguration neu: **Developer Tools** → **YAML** → **REST Commands**.

## Architektur

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

## Lizenz

MIT
