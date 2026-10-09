#import "godotx_firebase_analytics.h"
#import <Foundation/Foundation.h>

@import FirebaseAnalytics;
#import <AppTrackingTransparency/AppTrackingTransparency.h>

#include "core/object/class_db.h"

GodotxFirebaseAnalytics* GodotxFirebaseAnalytics::instance = nullptr;

void GodotxFirebaseAnalytics::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize"), &GodotxFirebaseAnalytics::initialize);
    ClassDB::bind_method(D_METHOD("log_event", "event_name", "params"), &GodotxFirebaseAnalytics::log_event);
    ClassDB::bind_method(D_METHOD("set_consent", "consent"), &GodotxFirebaseAnalytics::set_consent);
    ClassDB::bind_method(D_METHOD("set_analytics_collection_enabled", "enabled"), &GodotxFirebaseAnalytics::set_analytics_collection_enabled);
    ClassDB::bind_method(D_METHOD("set_user_id", "user_id"), &GodotxFirebaseAnalytics::set_user_id);
    ClassDB::bind_method(D_METHOD("set_user_property", "name", "value"), &GodotxFirebaseAnalytics::set_user_property);
    ClassDB::bind_method(D_METHOD("set_default_event_parameters", "params"), &GodotxFirebaseAnalytics::set_default_event_parameters);
    ClassDB::bind_method(D_METHOD("reset_analytics_data"), &GodotxFirebaseAnalytics::reset_analytics_data);
    ClassDB::bind_method(D_METHOD("request_app_instance_id"), &GodotxFirebaseAnalytics::request_app_instance_id);
    ClassDB::bind_method(D_METHOD("get_tcf_value", "key"), &GodotxFirebaseAnalytics::get_tcf_value);
    ClassDB::bind_method(D_METHOD("request_tracking_authorization"), &GodotxFirebaseAnalytics::request_tracking_authorization);
    ClassDB::bind_method(D_METHOD("get_tracking_status"), &GodotxFirebaseAnalytics::get_tracking_status);

    ADD_SIGNAL(MethodInfo("analytics_initialized", PropertyInfo(Variant::BOOL, "success")));
    ADD_SIGNAL(MethodInfo("analytics_event_logged", PropertyInfo(Variant::STRING, "event_name")));
    ADD_SIGNAL(MethodInfo("analytics_error", PropertyInfo(Variant::STRING, "message")));
    ADD_SIGNAL(MethodInfo("analytics_app_instance_id", PropertyInfo(Variant::STRING, "app_instance_id")));
    ADD_SIGNAL(MethodInfo("tracking_authorization", PropertyInfo(Variant::INT, "status")));
}

static NSDictionary* dictionary_to_nsdict(const Dictionary& dict) {
    NSMutableDictionary* nsDict = [NSMutableDictionary dictionary];
    Array keys = dict.keys();

    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        Variant value = dict[key];

        NSString* nsKey = [NSString stringWithUTF8String:key.utf8().get_data()];

        if (value.get_type() == Variant::STRING) {
            nsDict[nsKey] = [NSString stringWithUTF8String:String(value).utf8().get_data()];
        } else if (value.get_type() == Variant::INT) {
            nsDict[nsKey] = @((int64_t)value);
        } else if (value.get_type() == Variant::FLOAT) {
            nsDict[nsKey] = @((double)value);
        } else if (value.get_type() == Variant::BOOL) {
            // firebase analytics does NOT support boolean
            nsDict[nsKey] = @((bool)value ? 1 : 0);
        }
    }

    return nsDict;
}

GodotxFirebaseAnalytics* GodotxFirebaseAnalytics::get_singleton() {
    return instance;
}

void GodotxFirebaseAnalytics::initialize() {
    emit_signal("analytics_initialized", true);
}

void GodotxFirebaseAnalytics::log_event(String event_name, Dictionary params) {
    NSLog(@"[GodotxFirebaseAnalytics] log_event: %s", event_name.utf8().get_data());

    @try {
        NSString* nsEventName = [NSString stringWithUTF8String:event_name.utf8().get_data()];
        NSDictionary* nsParams = dictionary_to_nsdict(params);

        [FIRAnalytics logEventWithName:nsEventName parameters:nsParams];

        emit_signal("analytics_event_logged", event_name);
    }
    @catch (NSException *exception) {
        NSLog(@"[GodotxFirebaseAnalytics] Failed to log event: %@", exception.reason);
        emit_signal("analytics_error", String::utf8([exception.reason UTF8String]));
    }
}

static void put_consent(NSMutableDictionary* map, const Dictionary& consent, const char* key, FIRConsentType type) {
    if (!consent.has(key)) {
        return;
    }
    // consent constants are string-typed enums, so they are stored directly as keys and values without numeric boxing.
    String value = consent[key];
    map[type] = (value == "granted") ? FIRConsentStatusGranted : FIRConsentStatusDenied;
}

void GodotxFirebaseAnalytics::set_consent(Dictionary consent) {
    @try {
        NSMutableDictionary* map = [NSMutableDictionary dictionary];
        put_consent(map, consent, "analytics_storage", FIRConsentTypeAnalyticsStorage);
        put_consent(map, consent, "ad_storage", FIRConsentTypeAdStorage);
        put_consent(map, consent, "ad_user_data", FIRConsentTypeAdUserData);
        put_consent(map, consent, "ad_personalization", FIRConsentTypeAdPersonalization);
        if (map.count > 0) {
            [FIRAnalytics setConsent:map];
        }
    }
    @catch (NSException *exception) {
        NSLog(@"[GodotxFirebaseAnalytics] Failed to set consent: %@", exception.reason);
        emit_signal("analytics_error", String::utf8([exception.reason UTF8String]));
    }
}

void GodotxFirebaseAnalytics::set_analytics_collection_enabled(bool enabled) {
    @try {
        [FIRAnalytics setAnalyticsCollectionEnabled:enabled];
    }
    @catch (NSException *exception) {
        NSLog(@"[GodotxFirebaseAnalytics] Failed to set analytics collection enabled: %@", exception.reason);
        emit_signal("analytics_error", String::utf8([exception.reason UTF8String]));
    }
}

// kyulabs: user id · user properties · default params · reset · app instance id (2026-10-09)
static NSString* to_ns(const String& s) {
    return s.is_empty() ? nil : [NSString stringWithUTF8String:s.utf8().get_data()];
}

void GodotxFirebaseAnalytics::set_user_id(String user_id) {
    @try { [FIRAnalytics setUserID:to_ns(user_id)]; }
    @catch (NSException *exception) { emit_signal("analytics_error", String::utf8([exception.reason UTF8String])); }
}

void GodotxFirebaseAnalytics::set_user_property(String name, String value) {
    @try { [FIRAnalytics setUserPropertyString:to_ns(value) forName:to_ns(name)]; }
    @catch (NSException *exception) { emit_signal("analytics_error", String::utf8([exception.reason UTF8String])); }
}

void GodotxFirebaseAnalytics::set_default_event_parameters(Dictionary params) {
    @try { [FIRAnalytics setDefaultEventParameters:dictionary_to_nsdict(params)]; }
    @catch (NSException *exception) { emit_signal("analytics_error", String::utf8([exception.reason UTF8String])); }
}

void GodotxFirebaseAnalytics::reset_analytics_data() {
    [FIRAnalytics resetAnalyticsData];
}

void GodotxFirebaseAnalytics::request_app_instance_id() {
    NSString* id = [FIRAnalytics appInstanceID];
    emit_signal("analytics_app_instance_id", id ? String::utf8([id UTF8String]) : String());
}

// IAB TCF values written by the CMP (UMP) into NSUserDefaults, as a string ("" if unset).
String GodotxFirebaseAnalytics::get_tcf_value(String key) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithUTF8String:key.utf8().get_data()]];
    if (value == nil) return String();
    NSString* text = [value isKindOfClass:[NSString class]] ? (NSString*)value : [value description];
    return String::utf8([text UTF8String]);
}

// App Tracking Transparency (kyulabs): 0 notDetermined · 1 restricted · 2 denied · 3 authorized.
// Asks only while notDetermined (iOS shows the prompt once ever); the answer comes back on the main thread.
int GodotxFirebaseAnalytics::get_tracking_status() {
    if (@available(iOS 14, *)) {
        return (int)[ATTrackingManager trackingAuthorizationStatus];
    }
    return 3;
}

void GodotxFirebaseAnalytics::request_tracking_authorization() {
    if (@available(iOS 14, *)) {
        [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (instance) instance->emit_signal("tracking_authorization", (int)status);
            });
        }];
    } else {
        emit_signal("tracking_authorization", 3);
    }
}

GodotxFirebaseAnalytics::GodotxFirebaseAnalytics() {
    ERR_FAIL_COND(instance != NULL);
    instance = this;
    NSLog(@"[GodotxFirebaseAnalytics] Created");
}

GodotxFirebaseAnalytics::~GodotxFirebaseAnalytics() {
    if (instance == this) {
        instance = nullptr;
    }
}

