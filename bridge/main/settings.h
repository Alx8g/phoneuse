// What the bridge keeps across reboots (NVS): the Wi-Fi network it joins and the
// control keys it shares with the PCs allowed to use it.
#pragma once
#include <stdbool.h>
#include <stdint.h>

#define HOSTS 4        // PCs allowed at once; allowing a fifth drops the one allowed first
#define HOST_NAME 24   // a PC's name as the screen shows it (with its 0)

typedef struct {
    char ssid[33];
    char pass[65];
    uint8_t key[32];  // a key from BLE setup, waiting for the network to work (settings_save adds it)
    uint8_t hosts[HOSTS][32];  // each allowed PC's control key: signs its packets (HMAC-SHA256)
    char host_name[HOSTS][HOST_NAME];
    int nhosts;
    bool configured;
    bool quiet;  // forgotten by its PC: stay invisible until the setup button is held
} bridge_config_t;

extern bridge_config_t settings;
void settings_load(void);
void settings_save(void);  // the network, plus the BLE setup key (settings.key) if one waits
void settings_erase(void);
void settings_forget(void);      // erase everything and stay quiet from the next boot on
void settings_set_quiet(bool q);
// Allow a PC (its control key and name) and save. Returns the index of a PC dropped to
// make room (the first one allowed), or -1.
int settings_add_host(const uint8_t key[32], const char *name);
void settings_remove_host(int i);  // and save
