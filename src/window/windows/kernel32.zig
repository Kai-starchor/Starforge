pub const HMODULE = *opaque {};

/// Retrieves the process identifier of the calling process.
///
/// https://learn.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-getcurrentprocessid
pub extern "kernel32" fn GetCurrentProcessId() callconv(.winapi) u32;

/// Retrieves a module handle for the specified module. The module must have been loaded by the
/// calling process.
///
/// https://learn.microsoft.com/windows/win32/api/libloaderapi/nf-libloaderapi-getmodulehandlew
pub extern "kernel32" fn GetModuleHandleW(
    lpModuleName: ?[*:0]const u16,
) callconv(.winapi) ?HMODULE;
