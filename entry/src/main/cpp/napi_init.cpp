#include <napi/native_api.h>
#include "ace/xcomponent/native_interface_xcomponent.h"
#include "mpv/mpv_wrapper.h"
#include "mpv/mpv_subtitle.h"
#include "mpv/mpv_audio.h"
#include "mpv/mpv_video_info.h"
#include "mpv/mpv_playback.h"
#include "mpv/mpv_surface.h"
#include "mpv/mpv_loader.h"
#include "mpv/mpv_network.h"
#include "mpv/mpv_config.h"

namespace {
    // Main entry point - called on any 'import' instruction or 'XComponent' with 'libraryname' "libmpvnative"
    [[nodiscard]] napi_value Invoke(napi_env env, napi_value exports) {
        // Check if this is an XComponent request
        napi_value xComponentJS;
        napi_status const check = napi_get_named_property(env, exports, OH_NATIVE_XCOMPONENT_OBJ, &xComponentJS);
        
        if (check == napi_ok) {
            OH_NativeXComponent *xComponent;
            if (napi_unwrap(env, xComponentJS, reinterpret_cast<void **>(&xComponent)) == napi_ok) {
                // This is a UI/XComponent request - register GPU-NEXT callbacks
                static OH_NativeXComponent_Callback callbacks{
                    .OnSurfaceCreated = OnSurfaceCreated,
                    .OnSurfaceChanged = OnSurfaceChanged,
                    .OnSurfaceDestroyed = OnSurfaceDestroyed,
                    .DispatchTouchEvent = nullptr
                };
                
                OH_NativeXComponent_RegisterCallback(xComponent, &callbacks);
                return exports; // Return exports to indicate success
            }
        }
        
        // This is a regular ArkTS script request - register NAPI functions
        napi_property_descriptor desc[] = {
            {"create", nullptr, Create, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"isInitialized", nullptr, IsInitialized, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"loadVideo", nullptr, LoadVideo, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"destroy", nullptr, Destroy, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getSubtitleTracks", nullptr, GetSubtitleTracks, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"selectSubtitle", nullptr, SelectSubtitle, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"setSubtitleStyle", nullptr, SetSubtitleStyle, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getAudioTracks", nullptr, GetAudioTracks, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"selectAudio", nullptr, SelectAudio, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getCurrentAudioTrack", nullptr, GetCurrentAudioTrack, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getCurrentSubtitleTrack", nullptr, GetCurrentSubtitleTrack, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"seek", nullptr, Seek, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"pause", nullptr, Pause, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"play", nullptr, Play, nullptr, nullptr, nullptr, napi_default, nullptr},            {"setSpeed", nullptr, SetSpeed, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getCurrentPosition", nullptr, GetCurrentPosition, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getDuration", nullptr, GetDuration, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getCacheDuration", nullptr, GetCacheDuration, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getHardwareDecoder", nullptr, GetHardwareDecoder, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getVideoWidth", nullptr, GetVideoWidth, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getVideoHeight", nullptr, GetVideoHeight, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"setKeepAspect", nullptr, SetKeepAspect, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"command", nullptr, Command, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getNetworkSpeed", nullptr, GetNetworkSpeed, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"setHwdecMode", nullptr, SetHwdecModeNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getHwdecMode", nullptr, GetHwdecModeNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"setDecodeType", nullptr, SetDecodeTypeNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getDecodeType", nullptr, GetDecodeTypeNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"setCacheSize", nullptr, SetCacheSizeNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
            {"getCacheSize", nullptr, GetCacheSizeNapi, nullptr, nullptr, nullptr, napi_default, nullptr},
        };
        
        napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
        return exports;
    }

    __attribute__((constructor)) void RegisterMpvNativeModule() noexcept {
        napi_module appModule{
            .nm_version = 1,
            .nm_flags = 0U,
            .nm_filename = nullptr,
            .nm_register_func = &Invoke,
            .nm_modname = "libmpvnative",
            .nm_priv = nullptr,
            .reserved = {}
        };

        napi_module_register(&appModule);
    }
}

