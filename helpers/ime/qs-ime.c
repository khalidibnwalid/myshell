// qs-ime: a minimal Wayland input method for the shell's autocomplete.
//
// It registers as the seat's input method (zwp_input_method_v2). While a text field is
// focused it tells the shell what stands before the cursor, and on request replaces
// the word there. It draws nothing and predicts nothing: the shell does both.
//
// Two ways of knowing the text, chosen per text field:
//   - the field reports its text and keeps it up to date (GTK, Qt, Firefox): that
//     report is used, and words are replaced through the protocol;
//   - the field does not (Chromium, Electron): the typed keys are followed instead,
//     and a word is replaced by sending backspaces and then the new text.
//
// stdout, one JSON object per line:
//   {"e":"ready"}                    registered as the input method
//   {"e":"unavailable"}              another input method owns the seat (then exits)
//   {"e":"unsupported"}              the compositor lacks the protocols (then exits)
//   {"e":"active","v":true|false}    a text field got or lost the focus
//   {"e":"text","t":"…"}             text before the cursor ("" = nothing to complete)
//   {"e":"key","k":"tab"|"shifttab"|"esc"}   a key taken while the popup is open
//
// stdin, one command per line:
//   popup 1|0                  the popup is open: take Tab, Shift+Tab and Escape
//   replace BYTES CHARS TEXT   delete the last BYTES bytes (= CHARS characters) before
//                              the cursor, then insert TEXT
//   mute 1|0                   leave the focused app alone (terminals)
//   draw INDEX PREFIX WORDS    show the suggestions next to the text cursor: WORDS are
//                              tab separated, INDEX is the highlighted one (-1 = none),
//                              the first PREFIX characters of each are what was typed
//   undraw                     hide that list
//   style BG FG ACCENT ACCENTTEXT MUTED BORDER PX FAMILY   colours (#rrggbb or
//                              #aarrggbb), text size and font of the list
//   quit
//
// The list is drawn on the input method's popup surface, which the compositor puts
// next to the text cursor. The shell uses it for its "text cursor" placement; for the
// others it shows its own popup and never sends "draw".
//
// Password and PIN fields and terminals are left completely alone.
// Keys are only routed through this program while a text field it works in is focused;
// everything except the three keys above is passed on unchanged.
// QS_IME_DEBUG=1 logs what the text field reports to stderr.

#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include <cairo/cairo.h>
#include <pango/pangocairo.h>
#include <wayland-client.h>
#include <xkbcommon/xkbcommon.h>

#include "input-method-unstable-v2-client-protocol.h"
#include "virtual-keyboard-unstable-v1-client-protocol.h"

#define MAX_KEY 1024
#define CONTEXT_BYTES 192
// a field's report this soon after a key press is taken as the answer to that key
#define TYPING_WINDOW_MS 250
// after this long without a key the followed text is forgotten (the cursor may have moved)
#define IDLE_RESET_MS 4000

// text-input-v3 content purpose / hint
#define PURPOSE_PASSWORD 8
#define PURPOSE_PIN 9
#define PURPOSE_TERMINAL 13
#define HINT_HIDDEN_TEXT 0x40u
#define HINT_SENSITIVE 0x80u

static struct wl_display *display;
static struct wl_seat *seat;
static struct wl_compositor *compositor;
static uint32_t compositor_version;
static struct wl_shm *shm;
// the list next to the text cursor
static struct wl_surface *popup_surface;
static struct zwp_input_popup_surface_v2 *popup;
static bool popup_shown;
// drawn at twice the size, so it stays sharp on scaled screens
#define POPUP_SCALE 2
static double col_bg[4] = { 0.07, 0.07, 0.08, 0.96 };
static double col_fg[4] = { 0.9, 0.89, 0.91, 1 };
static double col_accent[4] = { 0.76, 0.76, 1, 1 };
static double col_accent_text[4] = { 0.07, 0.07, 0.08, 1 };
static double col_muted[4] = { 0.9, 0.89, 0.91, 0.62 };
static double col_border[4] = { 0.9, 0.89, 0.91, 0.22 };
static int font_px = 15;
static char font_family[128] = "sans-serif";
static struct zwp_input_method_manager_v2 *im_manager;
static struct zwp_virtual_keyboard_manager_v1 *vk_manager;
static struct zwp_input_method_v2 *im;
static struct zwp_virtual_keyboard_v1 *vk;
static struct zwp_input_method_keyboard_grab_v2 *grab;

static bool running = true;
static uint32_t done_count; // the serial for commit()

// state of the focused text field; "pending" is what arrived since the last done
static bool active, pending_active;
static bool pending_has_text;
static char *pending_text;
static uint32_t pending_cursor, pending_anchor;
static uint32_t pending_purpose, pending_hint;

static bool intercept;          // the popup is open
static bool muted;              // the shell asked to leave this app alone
static bool debug;

// the text before the cursor as followed from the keys
static char typed[CONTEXT_BYTES + 8];
static size_t typed_len;
// this field keeps its reported text up to date, so the report is trusted over the keys
static bool reliable;
static double last_key_ms;
static uint32_t backspace_key = 14; // KEY_BACKSPACE, looked up again in the keymap
static bool vk_has_keymap;
// the keyboard's own keymap, to tell which key is Tab or Escape on any layout or remapping
static struct xkb_context *xkb_ctx;
static struct xkb_keymap *xkb_map;
static struct xkb_state *xkb_st;
static uint8_t swallowed[MAX_KEY]; // keys taken on press: their release is taken too
static uint8_t forwarded[MAX_KEY]; // keys passed on as pressed
static char *last_sent;            // last "text" payload, to skip repeats
static bool force_send;

// --- output -----------------------------------------------------------------

static void out(const char *line) {
    // never block on the shell: a full pipe drops the line
    ssize_t r = write(STDOUT_FILENO, line, strlen(line));
    (void) r;
}

// {"e":"text","t":"<text>"} with the text JSON-escaped
static void send_text(const char *t, size_t len) {
    if (!force_send && last_sent && strlen(last_sent) == len && memcmp(last_sent, t, len) == 0)
        return;
    force_send = false;
    free(last_sent);
    last_sent = strndup(t, len);

    char *buf = malloc(len * 6 + 32);
    if (!buf)
        return;
    char *p = buf;
    p += sprintf(p, "{\"e\":\"text\",\"t\":\"");
    for (size_t i = 0; i < len; i++) {
        unsigned char c = (unsigned char) t[i];
        if (c == '"' || c == '\\') {
            *p++ = '\\';
            *p++ = (char) c;
        } else if (c < 0x20) {
            p += sprintf(p, "\\u%04x", c);
        } else {
            *p++ = (char) c;
        }
    }
    p += sprintf(p, "\"}\n");
    *p = 0;
    out(buf);
    free(buf);
}

static double now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000.0 + ts.tv_nsec / 1e6;
}

// --- the list next to the text cursor ---------------------------------------

struct shm_buffer {
    void *data;
    size_t size;
};

static void buffer_release(void *data, struct wl_buffer *buffer) {
    struct shm_buffer *b = data;
    wl_buffer_destroy(buffer);
    munmap(b->data, b->size);
    free(b);
}

static const struct wl_buffer_listener buffer_listener = {
    .release = buffer_release,
};

static void popup_rectangle(void *data, struct zwp_input_popup_surface_v2 *p, int32_t x, int32_t y, int32_t width, int32_t height) {
}

static const struct zwp_input_popup_surface_v2_listener popup_listener = {
    .text_input_rectangle = popup_rectangle,
};

static void undraw_popup(void) {
    if (!popup_surface || !popup_shown)
        return;
    wl_surface_attach(popup_surface, NULL, 0, 0);
    wl_surface_commit(popup_surface);
    popup_shown = false;
}

static void set_source(cairo_t *cr, const double c[4]) {
    cairo_set_source_rgba(cr, c[0], c[1], c[2], c[3]);
}

static void rounded_rect(cairo_t *cr, double x, double y, double w, double h, double r) {
    cairo_new_sub_path(cr);
    cairo_arc(cr, x + w - r, y + r, r, -G_PI / 2, 0);
    cairo_arc(cr, x + w - r, y + h - r, r, 0, G_PI / 2);
    cairo_arc(cr, x + r, y + h - r, r, G_PI / 2, G_PI);
    cairo_arc(cr, x + r, y + r, r, G_PI, 3 * G_PI / 2);
    cairo_close_path(cr);
}

// "hel" + "lo" -> hel<b>lo</b>: what was typed in regular weight, the rest in bold
static char *word_markup(const char *word, size_t prefix_chars) {
    const char *rest = word;
    while (prefix_chars > 0 && *rest) {
        rest++;
        while (((unsigned char) *rest & 0xC0) == 0x80)
            rest++;
        prefix_chars--;
    }
    char *head = g_markup_escape_text(word, rest - word);
    char *tail = g_markup_escape_text(rest, -1);
    char *markup = g_strdup_printf("%s<b>%s</b>", head, tail);
    g_free(head);
    g_free(tail);
    return markup;
}

static void draw_popup(int index, size_t prefix_chars, char **words, int count) {
    if (!popup_surface || !shm || count <= 0)
        return;
    const int pad = 6, row_h = 34, gap = 2, text_margin = 14, footer_h = 24, radius = 18;
    const char *hint = "Tab  next   ·   Esc  close";

    PangoFontDescription *font = pango_font_description_new();
    pango_font_description_set_family(font, font_family);
    pango_font_description_set_absolute_size(font, font_px * PANGO_SCALE);
    PangoFontDescription *small = pango_font_description_copy(font);
    pango_font_description_set_absolute_size(small, 11 * PANGO_SCALE);

    // how wide the widest line is
    cairo_surface_t *probe = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 1, 1);
    cairo_t *probe_cr = cairo_create(probe);
    PangoLayout *layout = pango_cairo_create_layout(probe_cr);
    char **markups = calloc((size_t) count, sizeof(char *));
    int text_w = 0, w = 0, h = 0;
    pango_layout_set_font_description(layout, font);
    for (int i = 0; i < count; i++) {
        markups[i] = word_markup(words[i], prefix_chars);
        pango_layout_set_markup(layout, markups[i], -1);
        pango_layout_get_pixel_size(layout, &w, &h);
        if (w > text_w)
            text_w = w;
    }
    pango_layout_set_font_description(layout, small);
    pango_layout_set_text(layout, hint, -1);
    pango_layout_get_pixel_size(layout, &w, &h);
    if (w > text_w)
        text_w = w;
    g_object_unref(layout);
    cairo_destroy(probe_cr);
    cairo_surface_destroy(probe);

    int width = text_w + (text_margin + pad) * 2;
    if (width < 170)
        width = 170;
    int height = pad * 2 + count * row_h + (count - 1) * gap + footer_h;

    int buf_w = width * POPUP_SCALE, buf_h = height * POPUP_SCALE, stride = buf_w * 4;
    size_t size = (size_t) stride * buf_h;
    int fd = memfd_create("qs-ime-popup", MFD_CLOEXEC);
    if (fd < 0 || ftruncate(fd, (off_t) size) < 0) {
        if (fd >= 0)
            close(fd);
        goto cleanup;
    }
    void *data = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (data == MAP_FAILED) {
        close(fd);
        goto cleanup;
    }
    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, (int32_t) size);
    struct wl_buffer *buffer = wl_shm_pool_create_buffer(pool, 0, buf_w, buf_h, stride, WL_SHM_FORMAT_ARGB8888);
    wl_shm_pool_destroy(pool);
    close(fd);
    struct shm_buffer *record = malloc(sizeof(*record));
    record->data = data;
    record->size = size;
    wl_buffer_add_listener(buffer, &buffer_listener, record);

    cairo_surface_t *surface = cairo_image_surface_create_for_data(data, CAIRO_FORMAT_ARGB32, buf_w, buf_h, stride);
    cairo_t *cr = cairo_create(surface);
    cairo_scale(cr, POPUP_SCALE, POPUP_SCALE);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);

    rounded_rect(cr, 0.5, 0.5, width - 1, height - 1, radius);
    set_source(cr, col_bg);
    cairo_fill_preserve(cr);
    set_source(cr, col_border);
    cairo_set_line_width(cr, 1);
    cairo_stroke(cr);

    layout = pango_cairo_create_layout(cr);
    // with a width set, right-to-left words line up on the right by themselves
    pango_layout_set_width(layout, (width - (text_margin + pad) * 2) * PANGO_SCALE);
    pango_layout_set_font_description(layout, font);
    for (int i = 0; i < count; i++) {
        int y = pad + i * (row_h + gap);
        if (i == index) {
            rounded_rect(cr, pad, y, width - pad * 2, row_h, 12);
            set_source(cr, col_accent);
            cairo_fill(cr);
        }
        set_source(cr, i == index ? col_accent_text : col_fg);
        pango_layout_set_markup(layout, markups[i], -1);
        pango_layout_get_pixel_size(layout, &w, &h);
        cairo_move_to(cr, pad + text_margin, y + (row_h - h) / 2.0);
        pango_cairo_show_layout(cr, layout);
    }
    pango_layout_set_font_description(layout, small);
    pango_layout_set_text(layout, hint, -1);
    pango_layout_get_pixel_size(layout, &w, &h);
    set_source(cr, col_muted);
    cairo_move_to(cr, pad + text_margin, pad + count * (row_h + gap) + (footer_h - gap - h) / 2.0);
    pango_cairo_show_layout(cr, layout);
    g_object_unref(layout);
    cairo_destroy(cr);
    cairo_surface_flush(surface);
    cairo_surface_destroy(surface);

    wl_surface_set_buffer_scale(popup_surface, POPUP_SCALE);
    wl_surface_attach(popup_surface, buffer, 0, 0);
    if (compositor_version >= 4)
        wl_surface_damage_buffer(popup_surface, 0, 0, buf_w, buf_h);
    else
        wl_surface_damage(popup_surface, 0, 0, width, height);
    wl_surface_commit(popup_surface);
    popup_shown = true;

cleanup:
    for (int i = 0; i < count; i++)
        g_free(markups[i]);
    free(markups);
    pango_font_description_free(font);
    pango_font_description_free(small);
}

// "#rrggbb" or "#aarrggbb"
static bool parse_color(const char *text, double out[4]) {
    if (text[0] != '#')
        return false;
    size_t len = strlen(text + 1);
    unsigned long value = strtoul(text + 1, NULL, 16);
    if (len == 6) {
        out[3] = 1;
    } else if (len == 8) {
        out[3] = ((value >> 24) & 0xff) / 255.0;
    } else {
        return false;
    }
    out[0] = ((value >> 16) & 0xff) / 255.0;
    out[1] = ((value >> 8) & 0xff) / 255.0;
    out[2] = (value & 0xff) / 255.0;
    return true;
}

// --- the text followed from the keys ----------------------------------------

static void typed_reset(void) {
    typed_len = 0;
    typed[0] = 0;
}

static void typed_append(const char *bytes, size_t len) {
    if (len == 0 || len > 8)
        return;
    if (typed_len + len > CONTEXT_BYTES) {
        // keep the newer half, starting at a character boundary
        size_t cut = typed_len / 2;
        while (cut < typed_len && ((unsigned char) typed[cut] & 0xC0) == 0x80)
            cut++;
        memmove(typed, typed + cut, typed_len - cut);
        typed_len -= cut;
    }
    memcpy(typed + typed_len, bytes, len);
    typed_len += len;
    typed[typed_len] = 0;
}

// removes the last n characters (not bytes)
static void typed_drop(size_t chars) {
    while (chars > 0 && typed_len > 0) {
        typed_len--;
        while (typed_len > 0 && ((unsigned char) typed[typed_len] & 0xC0) == 0x80)
            typed_len--;
        chars--;
    }
    typed[typed_len] = 0;
}

static void typed_set(const char *bytes, size_t len) {
    typed_reset();
    if (len > CONTEXT_BYTES) {
        bytes += len - CONTEXT_BYTES;
        len = CONTEXT_BYTES;
        while (len > 0 && ((unsigned char) *bytes & 0xC0) == 0x80) {
            bytes++;
            len--;
        }
    }
    memcpy(typed, bytes, len);
    typed_len = len;
    typed[typed_len] = 0;
}

// --- keyboard grab: pass every key on, except Tab / Escape while the popup is open ---

static void grab_keymap(void *data, struct zwp_input_method_keyboard_grab_v2 *g, uint32_t format, int32_t fd, uint32_t size) {
    if (format == WL_KEYBOARD_KEYMAP_FORMAT_XKB_V1) {
        char *text = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
        if (text != MAP_FAILED) {
            struct xkb_keymap *map = xkb_keymap_new_from_buffer(xkb_ctx, text, strnlen(text, size), XKB_KEYMAP_FORMAT_TEXT_V1, XKB_KEYMAP_COMPILE_NO_FLAGS);
            munmap(text, size);
            if (map) {
                xkb_state_unref(xkb_st);
                xkb_keymap_unref(xkb_map);
                xkb_map = map;
                xkb_st = xkb_state_new(map);
                // which key deletes backwards on this keyboard
                for (xkb_keycode_t code = xkb_keymap_min_keycode(map); code <= xkb_keymap_max_keycode(map); code++) {
                    const xkb_keysym_t *syms;
                    if (xkb_keymap_key_get_syms_by_level(map, code, 0, 0, &syms) > 0 && syms[0] == XKB_KEY_BackSpace) {
                        backspace_key = code - 8;
                        break;
                    }
                }
            }
        }
    }
    zwp_virtual_keyboard_v1_keymap(vk, format, fd, size);
    close(fd);
    vk_has_keymap = true;
}

static bool mod_active(const char *name) {
    return xkb_st && xkb_state_mod_name_is_active(xkb_st, name, XKB_STATE_MODS_EFFECTIVE) > 0;
}

static void grab_key(void *data, struct zwp_input_method_keyboard_grab_v2 *g, uint32_t serial, uint32_t time, uint32_t key, uint32_t state) {
    bool pressed = state == WL_KEYBOARD_KEY_STATE_PRESSED;
    if (key < MAX_KEY) {
        if (!pressed && swallowed[key]) {
            swallowed[key] = 0;
            return;
        }
        if (pressed && intercept && xkb_st) {
            // wl key codes are evdev codes; xkb counts from 8
            xkb_keysym_t sym = xkb_state_key_get_one_sym(xkb_st, key + 8);
            bool tab = sym == XKB_KEY_Tab || sym == XKB_KEY_ISO_Left_Tab || sym == XKB_KEY_KP_Tab;
            bool esc = sym == XKB_KEY_Escape;
            bool plain = !mod_active(XKB_MOD_NAME_CTRL) && !mod_active(XKB_MOD_NAME_ALT) && !mod_active(XKB_MOD_NAME_LOGO);
            if (plain && (tab || esc)) {
                swallowed[key] = 1;
                if (esc)
                    out("{\"e\":\"key\",\"k\":\"esc\"}\n");
                else if (sym == XKB_KEY_ISO_Left_Tab || mod_active(XKB_MOD_NAME_SHIFT))
                    out("{\"e\":\"key\",\"k\":\"shifttab\"}\n");
                else
                    out("{\"e\":\"key\",\"k\":\"tab\"}\n");
                return;
            }
        }
    }
    if (!vk_has_keymap)
        return;
    if (key < MAX_KEY)
        forwarded[key] = pressed;
    zwp_virtual_keyboard_v1_key(vk, time, key, state);

    if (!pressed || !xkb_st)
        return;
    // follow what this key does to the text before the cursor
    double now = now_ms();
    if (now - last_key_ms > IDLE_RESET_MS)
        typed_reset();
    last_key_ms = now;
    xkb_keysym_t sym = xkb_state_key_get_one_sym(xkb_st, key + 8);
    if (sym >= XKB_KEY_Shift_L && sym <= XKB_KEY_Hyper_R)
        return; // a modifier on its own changes nothing
    if (sym == XKB_KEY_ISO_Level3_Shift || sym == XKB_KEY_ISO_Level5_Shift || sym == XKB_KEY_ISO_Next_Group || sym == XKB_KEY_ISO_Prev_Group
        || sym == XKB_KEY_Caps_Lock || sym == XKB_KEY_Num_Lock)
        return;
    bool shortcut = mod_active(XKB_MOD_NAME_CTRL) || mod_active(XKB_MOD_NAME_ALT) || mod_active(XKB_MOD_NAME_LOGO);
    char utf8[16];
    int n = shortcut ? 0 : xkb_state_key_get_utf8(xkb_st, key + 8, utf8, sizeof(utf8));
    if (sym == XKB_KEY_BackSpace && !shortcut) {
        typed_drop(1);
    } else if (n > 0 && (unsigned char) utf8[0] >= 0x20 && utf8[0] != 0x7f) {
        typed_append(utf8, (size_t) n);
    } else {
        // arrows, Enter, Delete, shortcuts…: the cursor or the text moved in a way not followed
        typed_reset();
    }
    // a field that keeps its report current answers in a moment; until then go by the keys
    force_send = true;
    send_text(typed, typed_len);
}

static void grab_modifiers(void *data, struct zwp_input_method_keyboard_grab_v2 *g, uint32_t serial, uint32_t depressed, uint32_t latched, uint32_t locked, uint32_t group) {
    if (xkb_st)
        xkb_state_update_mask(xkb_st, depressed, latched, locked, 0, 0, group);
    if (vk_has_keymap)
        zwp_virtual_keyboard_v1_modifiers(vk, depressed, latched, locked, group);
}

static void grab_repeat_info(void *data, struct zwp_input_method_keyboard_grab_v2 *g, int32_t rate, int32_t delay) {
}

static const struct zwp_input_method_keyboard_grab_v2_listener grab_listener = {
    .keymap = grab_keymap,
    .key = grab_key,
    .modifiers = grab_modifiers,
    .repeat_info = grab_repeat_info,
};

static void take_keyboard(void) {
    if (grab)
        return;
    grab = zwp_input_method_v2_grab_keyboard(im);
    zwp_input_method_keyboard_grab_v2_add_listener(grab, &grab_listener, NULL);
}

static void give_keyboard_back(void) {
    if (!grab)
        return;
    // no key may stay "held" on the virtual keyboard once the real one takes over again
    for (uint32_t key = 0; key < MAX_KEY; key++) {
        if (forwarded[key] && vk_has_keymap)
            zwp_virtual_keyboard_v1_key(vk, 0, key, WL_KEYBOARD_KEY_STATE_RELEASED);
    }
    memset(forwarded, 0, sizeof(forwarded));
    memset(swallowed, 0, sizeof(swallowed));
    zwp_input_method_keyboard_grab_v2_release(grab);
    grab = NULL;
}

// --- input method -----------------------------------------------------------

static void im_activate(void *data, struct zwp_input_method_v2 *m) {
    // a new text field: nothing is known about it yet
    pending_active = true;
    pending_has_text = false;
    pending_purpose = 0;
    pending_hint = 0;
}

static void im_deactivate(void *data, struct zwp_input_method_v2 *m) {
    pending_active = false;
}

static void im_surrounding_text(void *data, struct zwp_input_method_v2 *m, const char *text, uint32_t cursor, uint32_t anchor) {
    free(pending_text);
    pending_text = strdup(text ? text : "");
    pending_cursor = cursor;
    pending_anchor = anchor;
    pending_has_text = true;
}

static void im_text_change_cause(void *data, struct zwp_input_method_v2 *m, uint32_t cause) {
}

static void im_content_type(void *data, struct zwp_input_method_v2 *m, uint32_t hint, uint32_t purpose) {
    pending_hint = hint;
    pending_purpose = purpose;
}

static bool ends_with(const char *text, size_t len, const char *tail, size_t tail_len) {
    return tail_len <= len && memcmp(text + len - tail_len, tail, tail_len) == 0;
}

static void im_done(void *data, struct zwp_input_method_v2 *m) {
    done_count++;

    if (pending_active != active) {
        active = pending_active;
        out(active ? "{\"e\":\"active\",\"v\":true}\n" : "{\"e\":\"active\",\"v\":false}\n");
        force_send = true;
        // a new field: nothing is known about how it reports, or about its text
        reliable = false;
        typed_reset();
        last_key_ms = 0;
    }

    bool private_field = pending_purpose == PURPOSE_PASSWORD || pending_purpose == PURPOSE_PIN || pending_purpose == PURPOSE_TERMINAL
        || (pending_hint & (HINT_HIDDEN_TEXT | HINT_SENSITIVE));

    if (!active || private_field || muted) {
        // not a field to complete in: stay out of the way entirely
        give_keyboard_back();
        undraw_popup();
        intercept = false;
        typed_reset();
        send_text("", 0);
        return;
    }

    take_keyboard();

    bool from_typing = now_ms() - last_key_ms < TYPING_WINDOW_MS;

    if (!pending_has_text || !pending_text) {
        // the field tells nothing about its text: only the keys are known.
        // A change that no key caused (a click, a paste) makes the followed text stale.
        if (!from_typing && typed_len > 0) {
            typed_reset();
            send_text("", 0);
        }
        return;
    }

    size_t len = strlen(pending_text);
    size_t cursor = pending_cursor <= len ? pending_cursor : len;
    bool selection = pending_cursor != pending_anchor;
    size_t start = cursor > CONTEXT_BYTES ? cursor - CONTEXT_BYTES : 0;
    // do not start in the middle of a UTF-8 character
    while (start < cursor && ((unsigned char) pending_text[start] & 0xC0) == 0x80)
        start++;
    const char *before = pending_text + start;
    size_t before_len = cursor - start;

    if (debug)
        fprintf(stderr, "report: before=\"%.*s\" selection=%d typed=\"%s\" reliable=%d from_typing=%d\n", (int) before_len, before, selection, typed, reliable, from_typing);

    if (!reliable && typed_len > 0 && !selection && ends_with(before, before_len, typed, typed_len))
        reliable = true; // the report shows what was just typed: this field keeps it current

    if (reliable) {
        if (selection) {
            typed_reset();
            send_text("", 0);
        } else {
            typed_set(before, before_len);
            send_text(typed, typed_len);
        }
        return;
    }

    // Not (yet) known to be current. A report right after a key is an old one and says
    // nothing; one that comes on its own means the cursor or the text changed elsewhere.
    if (!from_typing) {
        if (selection)
            typed_reset();
        else
            typed_set(before, before_len);
        send_text(typed, typed_len);
    }
}

static void im_unavailable(void *data, struct zwp_input_method_v2 *m) {
    out("{\"e\":\"unavailable\"}\n");
    running = false;
}

static const struct zwp_input_method_v2_listener im_listener = {
    .activate = im_activate,
    .deactivate = im_deactivate,
    .surrounding_text = im_surrounding_text,
    .text_change_cause = im_text_change_cause,
    .content_type = im_content_type,
    .done = im_done,
    .unavailable = im_unavailable,
};

// --- registry ---------------------------------------------------------------

static void registry_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
    if (strcmp(interface, wl_seat_interface.name) == 0 && !seat) {
        seat = wl_registry_bind(registry, name, &wl_seat_interface, 1);
    } else if (strcmp(interface, wl_compositor_interface.name) == 0) {
        compositor_version = version < 4 ? version : 4;
        compositor = wl_registry_bind(registry, name, &wl_compositor_interface, compositor_version);
    } else if (strcmp(interface, wl_shm_interface.name) == 0) {
        shm = wl_registry_bind(registry, name, &wl_shm_interface, 1);
    }
    else if (strcmp(interface, zwp_input_method_manager_v2_interface.name) == 0)
        im_manager = wl_registry_bind(registry, name, &zwp_input_method_manager_v2_interface, 1);
    else if (strcmp(interface, zwp_virtual_keyboard_manager_v1_interface.name) == 0)
        vk_manager = wl_registry_bind(registry, name, &zwp_virtual_keyboard_manager_v1_interface, 1);
}

static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t name) {
}

static const struct wl_registry_listener registry_listener = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

// --- commands from the shell ------------------------------------------------

static void handle_command(char *line) {
    if (strncmp(line, "popup ", 6) == 0) {
        intercept = line[6] == '1' && grab != NULL;
        if (!intercept)
            undraw_popup();
    } else if (strncmp(line, "replace ", 8) == 0) {
        char *end = NULL;
        unsigned long bytes = strtoul(line + 8, &end, 10);
        if (!end || *end != ' ')
            return;
        unsigned long chars = strtoul(end + 1, &end, 10);
        if (!end || *end != ' ' || !active || !grab)
            return;
        const char *text = end + 1;
        if (reliable) {
            if (bytes > 0)
                zwp_input_method_v2_delete_surrounding_text(im, (uint32_t) bytes, 0);
        } else if (vk_has_keymap) {
            // the field does not follow the protocol's delete: press backspace instead
            for (unsigned long i = 0; i < chars; i++) {
                zwp_virtual_keyboard_v1_key(vk, 0, backspace_key, WL_KEYBOARD_KEY_STATE_PRESSED);
                zwp_virtual_keyboard_v1_key(vk, 0, backspace_key, WL_KEYBOARD_KEY_STATE_RELEASED);
            }
        }
        zwp_input_method_v2_commit_string(im, text);
        zwp_input_method_v2_commit(im, done_count);
        // what stands before the cursor now; a field that reports its text confirms it
        typed_drop(chars);
        size_t text_len = strlen(text);
        if (typed_len + text_len > CONTEXT_BYTES)
            typed_reset();
        if (text_len <= CONTEXT_BYTES) {
            memcpy(typed + typed_len, text, text_len);
            typed_len += text_len;
            typed[typed_len] = 0;
        }
        last_key_ms = now_ms();
        force_send = true;
        if (!reliable)
            send_text(typed, typed_len);
    } else if (strncmp(line, "draw ", 5) == 0) {
        char *end = NULL;
        long index = strtol(line + 5, &end, 10);
        if (!end || *end != ' ')
            return;
        unsigned long prefix_chars = strtoul(end + 1, &end, 10);
        if (!end || *end != ' ' || !active || !grab)
            return;
        char *words[16];
        int count = 0;
        for (char *word = strtok(end + 1, "\t"); word && count < 16; word = strtok(NULL, "\t"))
            words[count++] = word;
        draw_popup((int) index, prefix_chars, words, count);
    } else if (strcmp(line, "undraw") == 0) {
        undraw_popup();
    } else if (strncmp(line, "style ", 6) == 0) {
        char colors[6][16];
        int px = 0, used = 0;
        if (sscanf(line + 6, "%15s %15s %15s %15s %15s %15s %d %n", colors[0], colors[1], colors[2], colors[3], colors[4], colors[5], &px, &used) < 7)
            return;
        parse_color(colors[0], col_bg);
        parse_color(colors[1], col_fg);
        parse_color(colors[2], col_accent);
        parse_color(colors[3], col_accent_text);
        parse_color(colors[4], col_muted);
        parse_color(colors[5], col_border);
        if (px >= 8 && px <= 40)
            font_px = px;
        const char *family = line + 6 + used;
        if (*family)
            snprintf(font_family, sizeof(font_family), "%s", family);
    } else if (strncmp(line, "mute ", 5) == 0) {
        bool want = line[5] == '1';
        if (want != muted) {
            muted = want;
            if (muted) {
                give_keyboard_back();
                undraw_popup();
                intercept = false;
                typed_reset();
                send_text("", 0);
            } else if (active) {
                take_keyboard();
            }
        }
    } else if (strcmp(line, "quit") == 0) {
        running = false;
    }
}

static char inbuf[4096];
static size_t inlen;

static void read_commands(void) {
    ssize_t n = read(STDIN_FILENO, inbuf + inlen, sizeof(inbuf) - inlen - 1);
    if (n == 0) {
        // the shell is gone
        running = false;
        return;
    }
    if (n < 0) {
        if (errno != EAGAIN && errno != EINTR)
            running = false;
        return;
    }
    inlen += (size_t) n;
    inbuf[inlen] = 0;
    char *start = inbuf;
    char *nl;
    while ((nl = strchr(start, '\n'))) {
        *nl = 0;
        handle_command(start);
        start = nl + 1;
    }
    inlen = strlen(start);
    memmove(inbuf, start, inlen + 1);
    if (inlen >= sizeof(inbuf) - 1)
        inlen = 0; // an overlong line: drop it
}

int main(void) {
    display = wl_display_connect(NULL);
    if (!display) {
        out("{\"e\":\"unsupported\"}\n");
        return 2;
    }
    struct wl_registry *registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &registry_listener, NULL);
    wl_display_roundtrip(display);
    if (!seat || !im_manager || !vk_manager) {
        out("{\"e\":\"unsupported\"}\n");
        return 2;
    }

    xkb_ctx = xkb_context_new(XKB_CONTEXT_NO_FLAGS);
    debug = getenv("QS_IME_DEBUG") != NULL;

    fcntl(STDOUT_FILENO, F_SETFL, fcntl(STDOUT_FILENO, F_GETFL) | O_NONBLOCK);
    fcntl(STDIN_FILENO, F_SETFL, fcntl(STDIN_FILENO, F_GETFL) | O_NONBLOCK);

    vk = zwp_virtual_keyboard_manager_v1_create_virtual_keyboard(vk_manager, seat);
    im = zwp_input_method_manager_v2_get_input_method(im_manager, seat);
    zwp_input_method_v2_add_listener(im, &im_listener, NULL);
    if (compositor && shm) {
        popup_surface = wl_compositor_create_surface(compositor);
        popup = zwp_input_method_v2_get_input_popup_surface(im, popup_surface);
        zwp_input_popup_surface_v2_add_listener(popup, &popup_listener, NULL);
        // it only shows: clicks go through to the window underneath
        struct wl_region *nothing = wl_compositor_create_region(compositor);
        wl_surface_set_input_region(popup_surface, nothing);
        wl_region_destroy(nothing);
    }
    wl_display_roundtrip(display);
    if (running)
        out("{\"e\":\"ready\"}\n");

    struct pollfd fds[2] = {
        { .fd = wl_display_get_fd(display), .events = POLLIN },
        { .fd = STDIN_FILENO, .events = POLLIN },
    };

    while (running) {
        while (wl_display_prepare_read(display) != 0)
            wl_display_dispatch_pending(display);
        if (wl_display_flush(display) < 0 && errno != EAGAIN) {
            wl_display_cancel_read(display);
            break;
        }
        if (poll(fds, 2, -1) < 0 && errno != EINTR) {
            wl_display_cancel_read(display);
            break;
        }
        if (fds[0].revents & POLLIN) {
            if (wl_display_read_events(display) < 0)
                break;
        } else {
            wl_display_cancel_read(display);
        }
        if (fds[0].revents & (POLLERR | POLLHUP))
            break;
        if (wl_display_dispatch_pending(display) < 0)
            break;
        if (fds[1].revents & (POLLIN | POLLHUP | POLLERR))
            read_commands();
        wl_display_flush(display);
    }

    // hand the keyboard back cleanly
    give_keyboard_back();
    wl_display_flush(display);
    wl_display_roundtrip(display);
    wl_display_disconnect(display);
    return 0;
}
