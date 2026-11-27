#pragma once
#include <CoreAudio/CoreAudio.h>

typedef struct HyperMacMixerState HyperMacMixerState;

HyperMacMixerState *HyperMacMixerCreate(void);
void HyperMacMixerSetGain(HyperMacMixerState *state, float gain);
void HyperMacMixerProcess(HyperMacMixerState *state,
                          const AudioBufferList *input,
                          AudioBufferList *output);
void HyperMacMixerDestroy(HyperMacMixerState *state);
