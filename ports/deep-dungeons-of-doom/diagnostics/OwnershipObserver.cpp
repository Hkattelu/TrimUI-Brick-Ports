// Private diagnostic adapter. Calls the unmodified native implementation once,
// observes its Boolean result, and returns the same FREObject to ActionScript.
// ABI definitions checked against Lightspark 6f07fd65 src/nativeextension/FREimpl.h
// and the public FRE native-extension interface. No Steam API implementation here.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <new>

using FREContext = void*;
using FREObject = void*;
using FREFunction = FREObject (*)(FREContext, void*, uint32_t, FREObject[]);
struct FRENamedFunction {
    const uint8_t* name;
    void* functionData;
    FREFunction function;
};
using FREContextInitializer = void (*)(void*, const uint8_t*, FREContext,
                                      uint32_t*, const FRENamedFunction**);
using FREContextFinalizer = void (*)(FREContext);
using FREInitializer = void (*)(void**, FREContextInitializer*, FREContextFinalizer*);
using FREFinalizer = void (*)(void*);
using FREGetUint = uint32_t (*)(FREObject, uint32_t*);

static HMODULE originalModule;
static FREContextInitializer originalContextInitializer;
static FREFinalizer originalFinalizer;
static FREFunction originalOwnershipFunction;
static FREGetUint getObjectAsBool;
static FREGetUint getObjectAsUint32;

static void Log(const char* message) {
    DWORD written = 0;
    HANDLE handle = GetStdHandle(STD_ERROR_HANDLE);
    if (handle && handle != INVALID_HANDLE_VALUE)
        WriteFile(handle, message, static_cast<DWORD>(strlen(message)), &written, nullptr);
}

static FREObject ObserveOwnership(FREContext context, void* functionData,
                                  uint32_t argc, FREObject argv[]) {
    uint32_t appId = 0;
    uint32_t appDecode = 0xffffffffu;
    if (argc == 1 && argv && getObjectAsUint32)
        appDecode = getObjectAsUint32(argv[0], &appId);

    // Preserve arguments, callback data, invocation count, and exact return object.
    FREObject result = originalOwnershipFunction(context, functionData, argc, argv);

    uint32_t value = 0;
    const uint32_t resultDecode = getObjectAsBool
        ? getObjectAsBool(result, &value) : 0xffffffffu;
    char message[256];
    snprintf(message, sizeof(message),
             "DDD_OBSERVER AIRSteam_IsSubscribedApp argc=%u app_id=%u "
             "app_decode=%u result_decode=%u value=%u original_object=%p\n",
             argc, appId, appDecode, resultDecode, value, result);
    Log(message);
    return result;
}

static void ObserveContext(void* extensionData, const uint8_t* contextType,
                           FREContext context, uint32_t* count,
                           const FRENamedFunction** functions) {
    originalContextInitializer(extensionData, contextType, context, count, functions);
    // Each returned table remains valid for this bounded diagnostic process.
    FRENamedFunction* copy = new (std::nothrow) FRENamedFunction[*count];
    if (!copy) {
        Log("DDD_OBSERVER allocation failed; original table preserved\n");
        return;
    }
    memcpy(copy, *functions, *count * sizeof(FRENamedFunction));
    for (uint32_t i = 0; i < *count; ++i) {
        if (copy[i].name && strcmp(reinterpret_cast<const char*>(copy[i].name),
                                  "AIRSteam_IsSubscribedApp") == 0) {
            originalOwnershipFunction = copy[i].function;
            copy[i].function = &ObserveOwnership;
            Log("DDD_OBSERVER installed pass-through ownership observation\n");
        }
    }
    *functions = copy;
}

extern "C" __declspec(dllexport)
void ExtInitializerFRESteamWorks(void** extensionData, FREContextInitializer* initialize,
                                FREContextFinalizer* finalize) {
    *initialize = nullptr;
    *finalize = nullptr;
    HMODULE self = nullptr;
    GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                      GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                      reinterpret_cast<LPCWSTR>(&ExtInitializerFRESteamWorks), &self);
    wchar_t path[32768];
    const DWORD length = GetModuleFileNameW(self, path, 32768);
    if (length == 0 || length >= 32768) {
        Log("DDD_OBSERVER could not resolve own module path\n");
        return;
    }
    wchar_t* slash = wcsrchr(path, L'\\');
    if (!slash) return;
    const wchar_t originalName[] = L"FRESteamWorks-original-64.dll";
    if (static_cast<size_t>(slash - path) + _countof(originalName) + 1 >= _countof(path))
        return;
    wcscpy_s(slash + 1, _countof(path) - (slash + 1 - path), originalName);
    originalModule = LoadLibraryW(path);
    if (!originalModule) {
        char message[128];
        snprintf(message, sizeof(message), "DDD_OBSERVER original DLL load failed error=%lu\n", GetLastError());
        Log(message);
        return;
    }
    auto originalInitialize = reinterpret_cast<FREInitializer>(
        GetProcAddress(originalModule, "ExtInitializerFRESteamWorks"));
    originalFinalizer = reinterpret_cast<FREFinalizer>(
        GetProcAddress(originalModule, "ExtFinalizerFRESteamWorks"));
    if (!originalInitialize) {
        Log("DDD_OBSERVER original initializer missing\n");
        return;
    }
    originalInitialize(extensionData, &originalContextInitializer, finalize);
    HMODULE air = GetModuleHandleW(L"Adobe AIR.dll");
    getObjectAsBool = reinterpret_cast<FREGetUint>(GetProcAddress(air, "FREGetObjectAsBool"));
    getObjectAsUint32 = reinterpret_cast<FREGetUint>(GetProcAddress(air, "FREGetObjectAsUint32"));
    *initialize = originalContextInitializer ? &ObserveContext : nullptr;
}

extern "C" __declspec(dllexport)
void ExtFinalizerFRESteamWorks(void* extensionData) {
    if (originalFinalizer) originalFinalizer(extensionData);
}
