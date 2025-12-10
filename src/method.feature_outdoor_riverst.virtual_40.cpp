// Decompiled: method.feature_outdoor_riverst.virtual_40
// This is the non-deleting virtual destructor for feature_outdoor_riverst
// Assembly:
//   0x00a10c10  mov qword [rdi], 0x1543150   ; set vtable
//   0x00a10c17  jmp 0xa10b60                 ; tail call to parent destructor
//
// The function simply sets the vtable to feature_outdoor_riverst's vtable
// then tail-calls the parent featurest destructor (at 0xa10b60).
//
// Since feature_outdoor_riverst adds no new members, its destructor is trivial
// and just calls the parent destructor.

// Forward declaration of parent destructor
extern "C" void _ZN9featurestD2Ev(void* _this);

struct feature_outdoor_riverst;

// vtable pointer - will be set to proper vtable by linker
extern "C" void* _ZTV23feature_outdoor_riverst[];

extern "C" void _ZN23feature_outdoor_riverstD2Ev(feature_outdoor_riverst* _this) {
    // Set vtable to feature_outdoor_riverst vtable (slot 2 is first virtual function)
    *(void**)_this = &_ZTV23feature_outdoor_riverst[2];
    // Tail call parent destructor
    _ZN9featurestD2Ev(_this);
}
