// Tiny Wayland test window for the workspace tests: opens one plain
// window (a grey square), prints "mapped" once it is up, and quits when
// the compositor asks it to close. No GPU needed, so it also runs in a
// headless compositor.
//   wl-window <title>
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/mman.h>
#include <wayland-client.h>
#include "xdg-shell-client-protocol.h"

static struct wl_compositor *comp;
static struct wl_shm *shm;
static struct xdg_wm_base *wm;
static struct wl_surface *surf;
static int done, mapped;

static void ping(void *d, struct xdg_wm_base *b, uint32_t s) { xdg_wm_base_pong(b, s); }
static const struct xdg_wm_base_listener wm_l = { ping };

static void reg_add(void *d, struct wl_registry *r, uint32_t id, const char *i, uint32_t v) {
    if (!strcmp(i, "wl_compositor")) comp = wl_registry_bind(r, id, &wl_compositor_interface, 4);
    else if (!strcmp(i, "wl_shm")) shm = wl_registry_bind(r, id, &wl_shm_interface, 1);
    else if (!strcmp(i, "xdg_wm_base")) {
        wm = wl_registry_bind(r, id, &xdg_wm_base_interface, 1);
        xdg_wm_base_add_listener(wm, &wm_l, NULL);
    }
}
static void reg_del(void *d, struct wl_registry *r, uint32_t id) {}
static const struct wl_registry_listener reg_l = { reg_add, reg_del };

static void draw(int w, int h) {
    int stride = w * 4, size = stride * h;
    int fd = memfd_create("wl-window", 0);
    if (fd < 0 || ftruncate(fd, size)) exit(2);
    void *p = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    memset(p, 0x55, size);
    struct wl_shm_pool *pool = wl_shm_create_pool(shm, fd, size);
    struct wl_buffer *b = wl_shm_pool_create_buffer(pool, 0, w, h, stride, WL_SHM_FORMAT_XRGB8888);
    wl_shm_pool_destroy(pool);
    close(fd);
    wl_surface_attach(surf, b, 0, 0);
    wl_surface_damage(surf, 0, 0, w, h);
    wl_surface_commit(surf);
}

static void xs_conf(void *d, struct xdg_surface *x, uint32_t serial) {
    xdg_surface_ack_configure(x, serial);
    draw(300, 200);
    if (!mapped) { mapped = 1; puts("mapped"); fflush(stdout); }
}
static const struct xdg_surface_listener xs_l = { xs_conf };

static void tl_conf(void *d, struct xdg_toplevel *t, int32_t w, int32_t h, struct wl_array *s) {}
static void tl_close(void *d, struct xdg_toplevel *t) { done = 1; }
static const struct xdg_toplevel_listener tl_l = { tl_conf, tl_close };

int main(int argc, char **argv) {
    struct wl_display *dpy = wl_display_connect(NULL);
    if (!dpy) { fputs("wl-window: no Wayland display\n", stderr); return 1; }
    struct wl_registry *reg = wl_display_get_registry(dpy);
    wl_registry_add_listener(reg, &reg_l, NULL);
    wl_display_roundtrip(dpy);
    if (!comp || !shm || !wm) { fputs("wl-window: missing globals\n", stderr); return 1; }
    surf = wl_compositor_create_surface(comp);
    struct xdg_surface *xs = xdg_wm_base_get_xdg_surface(wm, surf);
    xdg_surface_add_listener(xs, &xs_l, NULL);
    struct xdg_toplevel *tl = xdg_surface_get_toplevel(xs);
    xdg_toplevel_add_listener(tl, &tl_l, NULL);
    xdg_toplevel_set_title(tl, argc > 1 ? argv[1] : "test");
    xdg_toplevel_set_app_id(tl, "zexos-test");
    wl_surface_commit(surf);
    while (!done && wl_display_dispatch(dpy) != -1) {}
    return 0;
}
