#include "TrackpadBridge.h"
#include <CoreFoundation/CoreFoundation.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stddef.h>
// Undocumented MultitouchSupport ABI. Isolated here and loaded at runtime.
// No private framework is linked into the executable.
typedef struct { float x, y; } OLPoint;
typedef struct { OLPoint position, velocity; } OLVector;
typedef struct {
    int32_t frame; double timestamp;
    int32_t identifier, state, finger, hand;
    OLVector normalized; float quality; int32_t reserved1;
    float angle, major, minor; OLVector absolute;
    int32_t reserved2, reserved3; float density;
} OLContact;
_Static_assert(sizeof(OLContact) == 96, "Unexpected trackpad contact ABI");
typedef void (*FrameCallback)(void *, OLContact *, int, double, int);
static void *library;
static CFArrayRef devices;
static void (*registerFrame)(void *, FrameCallback);
static void (*unregisterFrame)(void *, FrameCallback);
static void (*startDevice)(void *, int);
static void (*stopDevice)(void *);
static OLTouchCallback receiver;
static pthread_mutex_t callbackLock = PTHREAD_MUTEX_INITIALIZER;
static void frame(void *device, OLContact *contacts, int count, double timestamp, int frameNumber) {
    if (count < 0 || count > 16) return;
    float xy[32]; int live = 0;
    for (int i = 0; i < count; i++) {
        if (contacts[i].state != 3 && contacts[i].state != 4) continue;
        float x = contacts[i].normalized.position.x, y = contacts[i].normalized.position.y;
        if (x < 0 || x > 1 || y < 0 || y > 1) continue;
        xy[live * 2] = x; xy[live * 2 + 1] = y; live++;
    }
    pthread_mutex_lock(&callbackLock);
    if (receiver) receiver((uintptr_t)device, xy, live);
    pthread_mutex_unlock(&callbackLock);
}
void OLTrackpadStop(void) {
    pthread_mutex_lock(&callbackLock); receiver = NULL; pthread_mutex_unlock(&callbackLock);
    if (devices) {
        for (CFIndex i = 0; i < CFArrayGetCount(devices); i++) {
            void *device = (void *)CFArrayGetValueAtIndex(devices, i);
            unregisterFrame(device, frame); stopDevice(device);
        }
        CFRelease(devices); devices = NULL;
    }
    // Keep the dylib loaded: the framework can still have callbacks in flight.
}
bool OLTrackpadStart(OLTouchCallback callback) {
    OLTrackpadStop();
    if (!library) library = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW | RTLD_LOCAL);
    if (!library) return false;
    CFArrayRef (*createList)(void) = dlsym(library, "MTDeviceCreateList");
    registerFrame = dlsym(library, "MTRegisterContactFrameCallback");
    unregisterFrame = dlsym(library, "MTUnregisterContactFrameCallback");
    startDevice = dlsym(library, "MTDeviceStart"); stopDevice = dlsym(library, "MTDeviceStop");
    if (!createList || !registerFrame || !unregisterFrame || !startDevice || !stopDevice) return false;
    devices = createList();
    if (!devices || CFArrayGetCount(devices) == 0) { if (devices) CFRelease(devices); devices = NULL; return false; }
    pthread_mutex_lock(&callbackLock); receiver = callback; pthread_mutex_unlock(&callbackLock);
    for (CFIndex i = 0; i < CFArrayGetCount(devices); i++) {
        void *device = (void *)CFArrayGetValueAtIndex(devices, i);
        registerFrame(device, frame); startDevice(device, 0);
    }
    return true;
}
