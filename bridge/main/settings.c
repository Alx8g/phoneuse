#include "settings.h"

#include <stdio.h>
#include <string.h>

#include "bridge.h"
#include "nvs.h"
#include "nvs_flash.h"

bridge_config_t settings;

void settings_load(void) {
    esp_err_t e = nvs_flash_init();
    if (e == ESP_ERR_NVS_NO_FREE_PAGES || e == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        nvs_flash_erase();
        nvs_flash_init();
    }
    memset(&settings, 0, sizeof settings);
    nvs_handle_t h;
    if (nvs_open("bridge", NVS_READONLY, &h) != ESP_OK) return;
    size_t n = sizeof settings.ssid;
    bool ok = nvs_get_str(h, "ssid", settings.ssid, &n) == ESP_OK;
    n = sizeof settings.pass;
    ok = ok && nvs_get_str(h, "pass", settings.pass, &n) == ESP_OK;
    n = sizeof settings.hosts;
    if (nvs_get_blob(h, "hosts", settings.hosts, &n) == ESP_OK && n % 32 == 0) {
        settings.nhosts = n / 32;
        n = sizeof settings.host_name;
        nvs_get_blob(h, "names", settings.host_name, &n);
    } else {  // firmware before 0.3: one key, from the PC that set it up
        n = 32;
        if (nvs_get_blob(h, "key", settings.hosts[0], &n) == ESP_OK && n == 32) settings.nhosts = 1;
    }
    settings.configured = ok && settings.nhosts > 0;
    uint8_t q = 0;
    settings.quiet = nvs_get_u8(h, "quiet", &q) == ESP_OK && q;
    nvs_close(h);
}

void settings_save(void) {
    nvs_handle_t h;
    if (nvs_open("bridge", NVS_READWRITE, &h) != ESP_OK) return;
    nvs_set_str(h, "ssid", settings.ssid);
    nvs_set_str(h, "pass", settings.pass);
    nvs_commit(h);
    nvs_close(h);
    static const uint8_t none[32];
    if (memcmp(settings.key, none, 32)) {  // BLE setup's key: that PC is allowed now
        int dropped = settings_add_host(settings.key, "set up over Bluetooth");
        if (dropped >= 0) link_host_removed(dropped);
        memset(settings.key, 0, 32);
    }
    settings.configured = settings.nhosts > 0;
}

static void save_hosts(void) {
    nvs_handle_t h;
    if (nvs_open("bridge", NVS_READWRITE, &h) != ESP_OK) return;
    nvs_set_blob(h, "hosts", settings.hosts, settings.nhosts * 32);
    nvs_set_blob(h, "names", settings.host_name, settings.nhosts * HOST_NAME);
    nvs_erase_key(h, "key");  // the old single key now lives in hosts
    nvs_commit(h);
    nvs_close(h);
}

int settings_add_host(const uint8_t key[32], const char *name) {
    for (int i = 0; i < settings.nhosts; i++)
        if (!memcmp(settings.hosts[i], key, 32)) return -1;  // allowed already
    int dropped = -1;
    if (settings.nhosts == HOSTS) {
        dropped = 0;
        memmove(settings.hosts[0], settings.hosts[1], (HOSTS - 1) * 32);
        memmove(settings.host_name[0], settings.host_name[1], (HOSTS - 1) * HOST_NAME);
        settings.nhosts--;
    }
    memcpy(settings.hosts[settings.nhosts], key, 32);
    snprintf(settings.host_name[settings.nhosts], HOST_NAME, "%s", name);
    settings.nhosts++;
    save_hosts();
    settings.configured = settings.ssid[0] != 0;
    return dropped;
}

void settings_remove_host(int i) {
    if (i < 0 || i >= settings.nhosts) return;
    memmove(settings.hosts[i], settings.hosts[i + 1], (settings.nhosts - i - 1) * 32);
    memmove(settings.host_name[i], settings.host_name[i + 1], (settings.nhosts - i - 1) * HOST_NAME);
    settings.nhosts--;
    memset(settings.hosts[settings.nhosts], 0, 32);
    save_hosts();
    settings.configured = settings.nhosts > 0 && settings.ssid[0];
}

void settings_erase(void) {
    nvs_handle_t h;
    if (nvs_open("bridge", NVS_READWRITE, &h) == ESP_OK) {
        nvs_erase_all(h);
        nvs_commit(h);
        nvs_close(h);
    }
    memset(&settings, 0, sizeof settings);
}

void settings_set_quiet(bool q) {
    settings.quiet = q;
    nvs_handle_t h;
    if (nvs_open("bridge", NVS_READWRITE, &h) != ESP_OK) return;
    if (q)
        nvs_set_u8(h, "quiet", 1);
    else
        nvs_erase_key(h, "quiet");
    nvs_commit(h);
    nvs_close(h);
}

void settings_forget(void) {
    settings_erase();
    settings_set_quiet(true);
}
