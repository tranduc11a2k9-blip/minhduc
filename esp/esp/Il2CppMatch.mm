//
//  Il2CppMatch.mm — resolve MatchGame through the il2cpp runtime API.
//
//  Why: the hardcoded GameFacadeTypeInfo offset (0xC012848) drifts every FF
//  season, and blind scans miss. The il2cpp runtime exports
//  il2cpp_domain_get / il2cpp_domain_get_assemblies / il2cpp_assembly_get_image
//  / il2cpp_class_from_name — these are engine APIs, identical across game
//  revisions. We call them in the FreeFire process via the RemoteCall engine
//  (dlsym by name — same primitives the SpringBoard overlay uses).
//
//  Chain:
//    domain = il2cpp_domain_get()
//    n, assemblies = il2cpp_domain_get_assemblies(domain, &n)
//    for each assembly: image = il2cpp_assembly_get_image(asm)
//      klass = il2cpp_class_from_name(image, "", "GameFacade")   // namespace ""
//      if klass: statics = klass->static_fields (offset 0xB8)
//        matchGame = *(statics + kCurrentMatchGame)              // 0x8
//
#import "Il2CppMatch.h"
#import "RemoteCall.h"
#import "remote_objc.h"
#import "GameOffsets.h"

// Remote helpers re-exported by remote_objc/RemoteCall
extern "C" uint64_t r_dlsym_call(int timeout, const char *fnName,
                                 uint64_t a0, uint64_t a1, uint64_t a2, uint64_t a3,
                                 uint64_t a4, uint64_t a5, uint64_t a6, uint64_t a7);

static inline bool kptr(uint64_t a) { return a > 0x100000000ULL; }

static uint64_t il2cpp_fn(const char *name) {
    // dlsym inside the FreeFire process resolves UnityFramework exports.
    uint64_t fn = r_dlsym_call(R_TIMEOUT, name, 0,0,0,0,0,0,0,0);
    return kptr(fn) ? fn : 0;
}

static uint64_t il2cpp_call(int timeout, const char *fnName,
                            uint64_t a0 = 0, uint64_t a1 = 0, uint64_t a2 = 0, uint64_t a3 = 0) {
    uint64_t fn = il2cpp_fn(fnName);
    if (!fn) return 0;
    return do_remote_call_stable_addr(timeout, fn, fnName, a0, a1, a2, a3, 0, 0, 0, 0);
}

uint64_t Il2CppResolveMatchGame(void) {
    // 1. domain
    uint64_t domain = il2cpp_call(5000, "il2cpp_domain_get");
    if (!kptr(domain)) return 0;

    // 2. assemblies array (returns Il2CppAssembly** + count via out-param).
    //    Out-param must be remote memory.
    uint64_t countBuf = r_dlsym_call(R_TIMEOUT, "malloc", 8, 0,0,0,0,0,0,0);
    if (!kptr(countBuf)) return 0;
    remote_write64(countBuf, 0);
    uint64_t asms = il2cpp_call(8000, "il2cpp_domain_get_assemblies", domain, countBuf, 0, 0);
    uint64_t count = remote_read64(countBuf);
    r_dlsym_call(R_TIMEOUT, "free", countBuf, 0,0,0,0,0,0,0);
    if (!kptr(asms) || count == 0 || count > 512) return 0;

    // 3. walk assemblies → images → find GameFacade class
    uint64_t selGetImage = 0; // unused; assembly_get_image is a C export
    (void)selGetImage;
    for (uint64_t i = 0; i < count; i++) {
        uint64_t asmPtr = remote_read64(asms + i * 8);
        if (!kptr(asmPtr)) continue;
        uint64_t image = il2cpp_call(5000, "il2cpp_assembly_get_image", asmPtr, 0, 0, 0);
        if (!kptr(image)) continue;

        // namespace "" + class name "GameFacade"
        uint64_t nsStr = r_alloc_str("");
        uint64_t clsStr = r_alloc_str("GameFacade");
        if (!kptr(nsStr) || !kptr(clsStr)) { r_free(nsStr); r_free(clsStr); continue; }
        uint64_t klass = il2cpp_call(5000, "il2cpp_class_from_name", image, nsStr, clsStr, 0);
        r_free(nsStr); r_free(clsStr);
        if (!kptr(klass)) continue;

        // 4. static fields (Il2CppClass.static_fields — 0xB8 holds on Unity
        //    2019-2021 arm64; GameOffsets table keeps kTypeInfoStatics)
        uint64_t statics = remote_read64(klass + (uint64_t)kTypeInfoStatics);
        if (!kptr(statics)) {
            // try common alternates
            static const uint64_t offs[] = { 0xB8, 0xB0, 0xC0 };
            for (size_t k = 0; k < 3; k++) {
                statics = remote_read64(klass + offs[k]);
                if (kptr(statics)) break;
            }
        }
        if (!kptr(statics)) continue;

        // 5. CurrentMatchGame (0x8) then CurrentGame (0x0) fallback
        uint64_t mg = remote_read64(statics + (uint64_t)kCurrentMatchGame);
        if (kptr(mg)) return mg;
        uint64_t cg = remote_read64(statics + (uint64_t)kCurrentGame);
        if (kptr(cg)) return cg;
    }
    return 0;
}
