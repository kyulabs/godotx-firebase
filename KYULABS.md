# kyulabs fork

Upstream godot-x/firebase **3.1.0** + additions to the **Analytics** module (other modules unchanged).
Release assets are overlays: install upstream 3.1.0 as usual, then copy the overlay over it.

| method | platforms | what |
|---|---|---|
| `set_user_id(id)` | iOS · Android | Analytics User-ID (`""` clears) |
| `set_user_property(name, value)` | iOS · Android | user property (`""` clears) |
| `set_default_event_parameters(dict)` | iOS · Android | params added to every event |
| `reset_analytics_data()` | iOS · Android | drop this app instance's Analytics data (consent withdrawn) |
| `request_app_instance_id()` | iOS · Android | → signal `analytics_app_instance_id(id)` |
| `get_tcf_value(key)` | iOS · Android | IAB TCF value stored by the CMP (Google UMP): `IABTCF_gdprApplies`, `IABTCF_PurposeConsents` … (`""` if unset) |
| `get_tracking_status()` | iOS | App Tracking Transparency: 0 not determined · 1 restricted · 2 denied · 3 authorized |
| `request_tracking_authorization()` | iOS | shows the ATT prompt if not asked yet → signal `tracking_authorization(status)`. Needs `NSUserTrackingUsageDescription` in Info.plist |

`firebase_analytics.gdip` also links `AppTrackingTransparency.framework`.

⚠️ On Android, `Engine.get_singleton(...).has_method()` does not see Java methods — ask `has_java_method()`.

## Build
Same as upstream (`make setup-godot`, then the Apple/Android targets for `firebase_analytics`). Only Godot's generated
headers are needed for the iOS plugin — `scons platform=ios target=template_release` can be stopped once `core/*.gen.h` exist.
