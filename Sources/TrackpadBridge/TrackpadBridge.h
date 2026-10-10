#ifndef OPENLAUNCHPAD_TRACKPAD_H
#define OPENLAUNCHPAD_TRACKPAD_H
#include <stdbool.h>
#include <stdint.h>
// Borrowed coordinates are valid only for the duration of the callback.
typedef void (*OLTouchCallback)(uintptr_t device, const float *xy, int count);
bool OLTrackpadStart(OLTouchCallback callback);
void OLTrackpadStop(void);
#endif
