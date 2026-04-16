; ModuleID = 'Evidence/ConstantTime/swift-llvm-metal-v1/swift/GoldilocksField.optimized.ll'
source_filename = "Evidence/ConstantTime/swift-llvm-metal-v1/swift/GoldilocksField.optimized.ll"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

%Ts6UInt64V = type <{ i64 }>
%T19SuperNeo_NuMetal_CT15GoldilocksFieldV = type <{ %Ts6UInt64V }>
%T19SuperNeo_NuMetal_CT14GoldilocksExt2V = type <{ %T19SuperNeo_NuMetal_CT15GoldilocksFieldV, %T19SuperNeo_NuMetal_CT15GoldilocksFieldV }>
%swift.type_descriptor = type opaque
%swift.protocol = type { ptr, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i32, i32, i32, i32, i32, i32 }
%swift.method_descriptor = type { i32, i32 }
%swift.protocol_requirement = type { i32, i32 }
%swift.vwtable = type { ptr, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i64, i64, i32, i32 }
%swift.enum_vwtable = type { ptr, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i64, i64, i32, i32, ptr, ptr, ptr }
%struct._SwiftEmptyArrayStorage = type { %struct.HeapObject, %struct._SwiftArrayBodyStorage }
%struct.HeapObject = type { ptr, %struct.InlineRefCountsPlaceholder }
%struct.InlineRefCountsPlaceholder = type { i64 }
%struct._SwiftArrayBodyStorage = type { i64, i64 }
%swift.type_metadata_record = type { i32 }
%swift.type = type { i64 }
%Ts6HasherV = type <{ %Ts6HasherV5_CoreV }>
%Ts6HasherV5_CoreV = type <{ %Ts6HasherV11_TailBufferV, %Ts6HasherV6_StateV }>
%Ts6HasherV11_TailBufferV = type <{ %Ts6UInt64V }>
%Ts6HasherV6_StateV = type <{ %Ts6UInt64V, %Ts6UInt64V, %Ts6UInt64V, %Ts6UInt64V, %Ts6UInt64V, %Ts6UInt64V, %Ts6UInt64V, %Ts6UInt64V }>
%TSa = type <{ %Ts12_ArrayBufferV }>
%Ts12_ArrayBufferV = type <{ %Ts14_BridgeStorageV }>
%Ts14_BridgeStorageV = type <{ ptr }>
%Ts5UInt8V = type <{ i8 }>
%swift.metadata_response = type { ptr, i64 }

@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZ" = constant %Ts6UInt64V <{ i64 -4294967295 }>, align 8
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV4zeroACvpZ" = constant %T19SuperNeo_NuMetal_CT15GoldilocksFieldV zeroinitializer, align 8
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3oneACvpZ" = constant %T19SuperNeo_NuMetal_CT15GoldilocksFieldV <{ %Ts6UInt64V <{ i64 1 }> }>, align 8
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V4zeroACvpZ" = constant %T19SuperNeo_NuMetal_CT14GoldilocksExt2V zeroinitializer, align 8
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V3oneACvpZ" = constant %T19SuperNeo_NuMetal_CT14GoldilocksExt2V <{ %T19SuperNeo_NuMetal_CT15GoldilocksFieldV <{ %Ts6UInt64V <{ i64 1 }> }>, %T19SuperNeo_NuMetal_CT15GoldilocksFieldV zeroinitializer }>, align 8
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V10nonResidueAA0F5FieldVvpZ" = constant %T19SuperNeo_NuMetal_CT15GoldilocksFieldV <{ %Ts6UInt64V <{ i64 7 }> }>, align 8
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOACs0F0AAWL" = linkonce_odr hidden local_unnamed_addr global ptr null, align 8
@"$ss23_ContiguousArrayStorageCMn" = external global %swift.type_descriptor, align 4
@"got.$ss23_ContiguousArrayStorageCMn" = private unnamed_addr constant ptr @"$ss23_ContiguousArrayStorageCMn"
@"$ss5UInt8VMn" = external global %swift.type_descriptor, align 4
@"got.$ss5UInt8VMn" = private unnamed_addr constant ptr @"$ss5UInt8VMn"
@"symbolic _____y_____G s23_ContiguousArrayStorageC s5UInt8V" = linkonce_odr hidden constant <{ i8, i32, [1 x i8], i8, i32, [1 x i8], i8 }> <{ i8 2, i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$ss23_ContiguousArrayStorageCMn" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i8, i32, [1 x i8], i8, i32, [1 x i8], i8 }>, ptr @"symbolic _____y_____G s23_ContiguousArrayStorageC s5UInt8V", i32 0, i32 1) to i64)) to i32), [1 x i8] c"y", i8 2, i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$ss5UInt8VMn" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i8, i32, [1 x i8], i8, i32, [1 x i8], i8 }>, ptr @"symbolic _____y_____G s23_ContiguousArrayStorageC s5UInt8V", i32 0, i32 4) to i64)) to i32), [1 x i8] c"G", i8 0 }>, section "__TEXT,__swift5_typeref, regular", no_sanitize_address, align 2
@"$ss23_ContiguousArrayStorageCys5UInt8VGMd" = linkonce_odr hidden global { ptr } zeroinitializer, align 8
@"$ss23_ContiguousArrayStorageCys5UInt8VGMR" = linkonce_odr hidden constant { i32, i32 } { i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic _____y_____G s23_ContiguousArrayStorageC s5UInt8V" to i64), i64 ptrtoint (ptr @"$ss23_ContiguousArrayStorageCys5UInt8VGMR" to i64)) to i32), i32 12 }, align 8
@".str.39.GoldilocksExt2 element must be 16 bytes" = private unnamed_addr constant [40 x i8] c"GoldilocksExt2 element must be 16 bytes\00"
@"$sSQMp" = external global %swift.protocol, align 4
@"got.$sSQMp" = private unnamed_addr constant ptr @"$sSQMp"
@"$sSQ2eeoiySbx_xtFZTq" = external global %swift.method_descriptor, align 4
@"got.$sSQ2eeoiySbx_xtFZTq" = private unnamed_addr constant ptr @"$sSQ2eeoiySbx_xtFZTq"
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAMcMK" = internal global [16 x ptr] zeroinitializer
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAMc" = constant { i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 } { i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSQMp" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAMc" to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMn" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAMc", i32 0, i32 1) to i64)) to i32), i32 0, i32 196608, i32 1, i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSQ2eeoiySbx_xtFZTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAMc", i32 0, i32 5) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAASQ2eeoiySbx_xtFZTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAMc", i32 0, i32 6) to i64)) to i32), i16 0, i16 1, i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAMcMK" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAMc", i32 0, i32 10) to i64)) to i32) }, section "__TEXT,__const", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVACSQAAWL" = linkonce_odr hidden local_unnamed_addr global ptr null, align 8
@"associated conformance 19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAASQ" = linkonce_odr hidden constant <{ i8, i8, i32, i8 }> <{ i8 -1, i8 7, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAASQWb" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i8, i8, i32, i8 }>, ptr @"associated conformance 19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAASQ", i32 0, i32 2) to i64)) to i32), i8 0 }>, section "__TEXT,__swift5_typeref, regular", no_sanitize_address, align 2
@"$sSHMp" = external global %swift.protocol, align 4
@"got.$sSHMp" = private unnamed_addr constant ptr @"$sSHMp"
@"$sSHSQTb" = external global %swift.protocol_requirement, align 4
@"got.$sSHSQTb" = private unnamed_addr constant ptr @"$sSHSQTb"
@"$sSH9hashValueSivgTq" = external global %swift.method_descriptor, align 4
@"got.$sSH9hashValueSivgTq" = private unnamed_addr constant ptr @"$sSH9hashValueSivgTq"
@"$sSH4hash4intoys6HasherVz_tFTq" = external global %swift.method_descriptor, align 4
@"got.$sSH4hash4intoys6HasherVz_tFTq" = private unnamed_addr constant ptr @"$sSH4hash4intoys6HasherVz_tFTq"
@"$sSH13_rawHashValue4seedS2i_tFTq" = external global %swift.method_descriptor, align 4
@"got.$sSH13_rawHashValue4seedS2i_tFTq" = private unnamed_addr constant ptr @"$sSH13_rawHashValue4seedS2i_tFTq"
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMcMK" = internal global [16 x ptr] zeroinitializer
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc" = constant { i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 } { i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSHMp" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc" to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMn" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc", i32 0, i32 1) to i64)) to i32), i32 0, i32 196608, i32 4, i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSHSQTb" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc", i32 0, i32 5) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr getelementptr (i8, ptr @"associated conformance 19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAASQ", i64 1) to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc", i32 0, i32 6) to i64)) to i32), i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSH9hashValueSivgTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc", i32 0, i32 7) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAASH9hashValueSivgTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc", i32 0, i32 8) to i64)) to i32), i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSH4hash4intoys6HasherVz_tFTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc", i32 0, i32 9) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAASH4hash4intoys6HasherVz_tFTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc", i32 0, i32 10) to i64)) to i32), i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSH13_rawHashValue4seedS2i_tFTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc", i32 0, i32 11) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAASH13_rawHashValue4seedS2i_tFTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc", i32 0, i32 12) to i64)) to i32), i16 0, i16 1, i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMcMK" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc", i32 0, i32 16) to i64)) to i32) }, section "__TEXT,__const", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAMcMK" = internal global [16 x ptr] zeroinitializer
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAMc" = constant { i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 } { i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSQMp" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAMc" to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMn" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAMc", i32 0, i32 1) to i64)) to i32), i32 0, i32 196608, i32 1, i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSQ2eeoiySbx_xtFZTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAMc", i32 0, i32 5) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAASQ2eeoiySbx_xtFZTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAMc", i32 0, i32 6) to i64)) to i32), i16 0, i16 1, i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAMcMK" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAMc", i32 0, i32 10) to i64)) to i32) }, section "__TEXT,__const", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VACSQAAWL" = linkonce_odr hidden local_unnamed_addr global ptr null, align 8
@"associated conformance 19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAASQ" = linkonce_odr hidden constant <{ i8, i8, i32, i8 }> <{ i8 -1, i8 7, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAASQWb" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i8, i8, i32, i8 }>, ptr @"associated conformance 19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAASQ", i32 0, i32 2) to i64)) to i32), i8 0 }>, section "__TEXT,__swift5_typeref, regular", no_sanitize_address, align 2
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMcMK" = internal global [16 x ptr] zeroinitializer
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc" = constant { i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 } { i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSHMp" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc" to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMn" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc", i32 0, i32 1) to i64)) to i32), i32 0, i32 196608, i32 4, i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSHSQTb" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc", i32 0, i32 5) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr getelementptr (i8, ptr @"associated conformance 19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAASQ", i64 1) to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc", i32 0, i32 6) to i64)) to i32), i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSH9hashValueSivgTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc", i32 0, i32 7) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAASH9hashValueSivgTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc", i32 0, i32 8) to i64)) to i32), i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSH4hash4intoys6HasherVz_tFTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc", i32 0, i32 9) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAASH4hash4intoys6HasherVz_tFTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc", i32 0, i32 10) to i64)) to i32), i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSH13_rawHashValue4seedS2i_tFTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc", i32 0, i32 11) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAASH13_rawHashValue4seedS2i_tFTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc", i32 0, i32 12) to i64)) to i32), i16 0, i16 1, i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMcMK" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc", i32 0, i32 16) to i64)) to i32) }, section "__TEXT,__const", no_sanitize_address, align 4
@"$ss5ErrorMp" = external global %swift.protocol, align 4
@"got.$ss5ErrorMp" = private unnamed_addr constant ptr @"$ss5ErrorMp"
@"$ss5ErrorP7_domainSSvgTq" = external global %swift.method_descriptor, align 4
@"got.$ss5ErrorP7_domainSSvgTq" = private unnamed_addr constant ptr @"$ss5ErrorP7_domainSSvgTq"
@"$ss5ErrorP5_codeSivgTq" = external global %swift.method_descriptor, align 4
@"got.$ss5ErrorP5_codeSivgTq" = private unnamed_addr constant ptr @"$ss5ErrorP5_codeSivgTq"
@"$ss5ErrorP9_userInfoyXlSgvgTq" = external global %swift.method_descriptor, align 4
@"got.$ss5ErrorP9_userInfoyXlSgvgTq" = private unnamed_addr constant ptr @"$ss5ErrorP9_userInfoyXlSgvgTq"
@"$ss5ErrorP19_getEmbeddedNSErroryXlSgyFTq" = external global %swift.method_descriptor, align 4
@"got.$ss5ErrorP19_getEmbeddedNSErroryXlSgyFTq" = private unnamed_addr constant ptr @"$ss5ErrorP19_getEmbeddedNSErroryXlSgyFTq"
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMcMK" = internal global [16 x ptr] zeroinitializer
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc" = constant { i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 } { i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$ss5ErrorMp" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc" to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMn" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc", i32 0, i32 1) to i64)) to i32), i32 0, i32 196608, i32 4, i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$ss5ErrorP7_domainSSvgTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc", i32 0, i32 5) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAsADP7_domainSSvgTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc", i32 0, i32 6) to i64)) to i32), i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$ss5ErrorP5_codeSivgTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc", i32 0, i32 7) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAsADP5_codeSivgTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc", i32 0, i32 8) to i64)) to i32), i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$ss5ErrorP9_userInfoyXlSgvgTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc", i32 0, i32 9) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAsADP9_userInfoyXlSgvgTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc", i32 0, i32 10) to i64)) to i32), i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$ss5ErrorP19_getEmbeddedNSErroryXlSgyFTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc", i32 0, i32 11) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAsADP19_getEmbeddedNSErroryXlSgyFTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc", i32 0, i32 12) to i64)) to i32), i16 0, i16 1, i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMcMK" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc", i32 0, i32 16) to i64)) to i32) }, section "__TEXT,__const", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAMcMK" = internal global [16 x ptr] zeroinitializer
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAMc" = constant { i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 } { i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSQMp" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAMc" to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMn" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAMc", i32 0, i32 1) to i64)) to i32), i32 0, i32 196608, i32 1, i32 add (i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$sSQ2eeoiySbx_xtFZTq" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAMc", i32 0, i32 5) to i64)) to i32), i32 1), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAASQ2eeoiySbx_xtFZTW" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAMc", i32 0, i32 6) to i64)) to i32), i16 0, i16 1, i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAMcMK" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i32, i32, i32, i32, i32, i16, i16, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAMc", i32 0, i32 10) to i64)) to i32) }, section "__TEXT,__const", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV" = unnamed_addr constant { i32 } zeroinitializer, align 4
@"$sBi64_WV" = external global ptr, align 8
@.str.19.SuperNeo_NuMetal_CT = private constant [20 x i8] c"SuperNeo_NuMetal_CT\00"
@"$s19SuperNeo_NuMetal_CTMXM" = linkonce_odr hidden constant <{ i32, i32, i32 }> <{ i32 0, i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @.str.19.SuperNeo_NuMetal_CT to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CTMXM", i32 0, i32 2) to i64)) to i32) }>, section "__TEXT,__constg_swiftt", align 4
@.str.15.GoldilocksField = private constant [16 x i8] c"GoldilocksField\00"
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMn" = constant <{ i32, i32, i32, i32, i32, i32, i32 }> <{ i32 81, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CTMXM" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMn", i32 0, i32 1) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @.str.15.GoldilocksField to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMn", i32 0, i32 2) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMa" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMn", i32 0, i32 3) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMF" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMn", i32 0, i32 4) to i64)) to i32), i32 1, i32 2 }>, section "__TEXT,__constg_swiftt", align 4
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMf" = internal constant <{ ptr, ptr, i64, ptr, i32, [4 x i8] }> <{ ptr null, ptr @"$sBi64_WV", i64 512, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMn", i32 0, [4 x i8] zeroinitializer }>, align 8
@"symbolic _____ 19SuperNeo_NuMetal_CT15GoldilocksFieldV" = linkonce_odr hidden constant <{ i8, i32, i8 }> <{ i8 1, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMn" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i8, i32, i8 }>, ptr @"symbolic _____ 19SuperNeo_NuMetal_CT15GoldilocksFieldV", i32 0, i32 1) to i64)) to i32), i8 0 }>, section "__TEXT,__swift5_typeref, regular", no_sanitize_address, align 2
@"$ss6UInt64VMn" = external global %swift.type_descriptor, align 4
@"got.$ss6UInt64VMn" = private unnamed_addr constant ptr @"$ss6UInt64VMn"
@"symbolic _____ s6UInt64V" = linkonce_odr hidden constant <{ i8, i32, i8 }> <{ i8 2, i32 trunc (i64 sub (i64 ptrtoint (ptr @"got.$ss6UInt64VMn" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i8, i32, i8 }>, ptr @"symbolic _____ s6UInt64V", i32 0, i32 1) to i64)) to i32), i8 0 }>, section "__TEXT,__swift5_typeref, regular", no_sanitize_address, align 2
@0 = private constant [9 x i8] c"rawValue\00", section "__TEXT,__swift5_reflstr, regular", no_sanitize_address
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMF" = internal constant { i32, i32, i16, i16, i32, i32, i32, i32 } { i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic _____ 19SuperNeo_NuMetal_CT15GoldilocksFieldV" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMF" to i64)) to i32), i32 0, i16 0, i16 12, i32 1, i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic _____ s6UInt64V" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMF", i32 0, i32 6) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @0 to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMF", i32 0, i32 7) to i64)) to i32) }, section "__TEXT,__swift5_fieldmd, regular", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VWV" = internal constant %swift.vwtable { ptr @__swift_memcpy16_8, ptr @__swift_noop_void_return, ptr @__swift_memcpy16_8, ptr @__swift_memcpy16_8, ptr @__swift_memcpy16_8, ptr @__swift_memcpy16_8, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2Vwet", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2Vwst", i64 16, i64 16, i32 7, i32 0 }, align 8
@.str.14.GoldilocksExt2 = private constant [15 x i8] c"GoldilocksExt2\00"
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMn" = constant <{ i32, i32, i32, i32, i32, i32, i32 }> <{ i32 81, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CTMXM" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMn", i32 0, i32 1) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @.str.14.GoldilocksExt2 to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMn", i32 0, i32 2) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMa" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMn", i32 0, i32 3) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMF" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMn", i32 0, i32 4) to i64)) to i32), i32 2, i32 2 }>, section "__TEXT,__constg_swiftt", align 4
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMf" = internal constant <{ ptr, ptr, i64, ptr, i32, i32 }> <{ ptr null, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VWV", i64 512, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMn", i32 0, i32 8 }>, align 8
@"symbolic _____ 19SuperNeo_NuMetal_CT14GoldilocksExt2V" = linkonce_odr hidden constant <{ i8, i32, i8 }> <{ i8 1, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMn" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i8, i32, i8 }>, ptr @"symbolic _____ 19SuperNeo_NuMetal_CT14GoldilocksExt2V", i32 0, i32 1) to i64)) to i32), i8 0 }>, section "__TEXT,__swift5_typeref, regular", no_sanitize_address, align 2
@1 = private constant [3 x i8] c"c0\00", section "__TEXT,__swift5_reflstr, regular", no_sanitize_address
@2 = private constant [3 x i8] c"c1\00", section "__TEXT,__swift5_reflstr, regular", no_sanitize_address
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMF" = internal constant { i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32 } { i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic _____ 19SuperNeo_NuMetal_CT14GoldilocksExt2V" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMF" to i64)) to i32), i32 0, i16 0, i16 12, i32 2, i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic _____ 19SuperNeo_NuMetal_CT15GoldilocksFieldV" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMF", i32 0, i32 6) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @1 to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMF", i32 0, i32 7) to i64)) to i32), i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic _____ 19SuperNeo_NuMetal_CT15GoldilocksFieldV" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMF", i32 0, i32 9) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @2 to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMF", i32 0, i32 10) to i64)) to i32) }, section "__TEXT,__swift5_fieldmd, regular", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOWV" = internal constant %swift.enum_vwtable { ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwCP", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwxx", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwcp", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwca", ptr @__swift_memcpy17_8, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwta", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwet", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwst", i64 17, i64 24, i32 35717127, i32 250, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwug", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwup", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwui" }, align 8
@.str.13.SuperNeoError = private constant [14 x i8] c"SuperNeoError\00"
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOMn" = constant <{ i32, i32, i32, i32, i32, i32, i32 }> <{ i32 82, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CTMXM" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMn", i32 0, i32 1) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @.str.13.SuperNeoError to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMn", i32 0, i32 2) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMa" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMn", i32 0, i32 3) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i32, i32, i32, i32, i32, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMn", i32 0, i32 4) to i64)) to i32), i32 5, i32 2 }>, section "__TEXT,__constg_swiftt", align 4
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOMf" = internal constant <{ ptr, ptr, i64, ptr }> <{ ptr null, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOWV", i64 513, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMn" }>, align 8
@"symbolic _____ 19SuperNeo_NuMetal_CT0aB5ErrorO" = linkonce_odr hidden constant <{ i8, i32, i8 }> <{ i8 1, i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMn" to i64), i64 ptrtoint (ptr getelementptr inbounds (<{ i8, i32, i8 }>, ptr @"symbolic _____ 19SuperNeo_NuMetal_CT0aB5ErrorO", i32 0, i32 1) to i64)) to i32), i8 0 }>, section "__TEXT,__swift5_typeref, regular", no_sanitize_address, align 2
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOMB" = internal constant { i32, i32, i32, i32, i32 } { i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic _____ 19SuperNeo_NuMetal_CT0aB5ErrorO" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMB" to i64)) to i32), i32 17, i32 65544, i32 24, i32 250 }, section "__TEXT,__swift5_builtin, regular", no_sanitize_address, align 4
@"\01l__swift5_reflection_descriptor" = private constant { i32, i32 } { i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic _____ 19SuperNeo_NuMetal_CT0aB5ErrorO" to i64), i64 ptrtoint (ptr @"\01l__swift5_reflection_descriptor" to i64)) to i32), i32 65536 }, section "__TEXT,__swift5_mpenum, regular", no_sanitize_address, align 4
@"symbolic SS" = linkonce_odr hidden constant <{ [2 x i8], i8 }> <{ [2 x i8] c"SS", i8 0 }>, section "__TEXT,__swift5_typeref, regular", no_sanitize_address, align 2
@3 = private constant [16 x i8] c"invalidEncoding\00", section "__TEXT,__swift5_reflstr, regular", no_sanitize_address
@4 = private constant [17 x i8] c"invalidParameter\00", section "__TEXT,__swift5_reflstr, regular", no_sanitize_address
@5 = private constant [22 x i8] c"randomnessUnavailable\00", section "__TEXT,__swift5_reflstr, regular", no_sanitize_address
@6 = private constant [13 x i8] c"metalFailure\00", section "__TEXT,__swift5_reflstr, regular", no_sanitize_address
@7 = private constant [19 x i8] c"verificationFailed\00", section "__TEXT,__swift5_reflstr, regular", no_sanitize_address
@8 = private constant [15 x i8] c"divisionByZero\00", section "__TEXT,__swift5_reflstr, regular", no_sanitize_address
@9 = private constant [17 x i8] c"metalUnavailable\00", section "__TEXT,__swift5_reflstr, regular", no_sanitize_address
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF" = internal constant { i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 } { i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic _____ 19SuperNeo_NuMetal_CT0aB5ErrorO" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF" to i64)) to i32), i32 0, i16 3, i16 12, i32 7, i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic SS" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", i32 0, i32 6) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @3 to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", i32 0, i32 7) to i64)) to i32), i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic SS" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", i32 0, i32 9) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @4 to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", i32 0, i32 10) to i64)) to i32), i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic SS" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", i32 0, i32 12) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @5 to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", i32 0, i32 13) to i64)) to i32), i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic SS" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", i32 0, i32 15) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @6 to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", i32 0, i32 16) to i64)) to i32), i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @"symbolic SS" to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", i32 0, i32 18) to i64)) to i32), i32 trunc (i64 sub (i64 ptrtoint (ptr @7 to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", i32 0, i32 19) to i64)) to i32), i32 0, i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @8 to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", i32 0, i32 22) to i64)) to i32), i32 0, i32 0, i32 trunc (i64 sub (i64 ptrtoint (ptr @9 to i64), i64 ptrtoint (ptr getelementptr inbounds ({ i32, i32, i16, i16, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32, i32 }, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", i32 0, i32 25) to i64)) to i32) }, section "__TEXT,__swift5_fieldmd, regular", no_sanitize_address, align 4
@"_swift_FORCE_LOAD_$_swiftFoundation_$_SuperNeo_NuMetal_CT" = weak_odr hidden constant ptr @"_swift_FORCE_LOAD_$_swiftFoundation"
@"_swift_FORCE_LOAD_$_swift_Builtin_float_$_SuperNeo_NuMetal_CT" = weak_odr hidden constant ptr @"_swift_FORCE_LOAD_$_swift_Builtin_float"
@"_swift_FORCE_LOAD_$_swiftObjectiveC_$_SuperNeo_NuMetal_CT" = weak_odr hidden constant ptr @"_swift_FORCE_LOAD_$_swiftObjectiveC"
@"_swift_FORCE_LOAD_$_swiftCoreFoundation_$_SuperNeo_NuMetal_CT" = weak_odr hidden constant ptr @"_swift_FORCE_LOAD_$_swiftCoreFoundation"
@"_swift_FORCE_LOAD_$_swiftDispatch_$_SuperNeo_NuMetal_CT" = weak_odr hidden constant ptr @"_swift_FORCE_LOAD_$_swiftDispatch"
@"_swift_FORCE_LOAD_$_swiftXPC_$_SuperNeo_NuMetal_CT" = weak_odr hidden constant ptr @"_swift_FORCE_LOAD_$_swiftXPC"
@"_swift_FORCE_LOAD_$_swiftIOKit_$_SuperNeo_NuMetal_CT" = weak_odr hidden constant ptr @"_swift_FORCE_LOAD_$_swiftIOKit"
@_swiftEmptyArrayStorage = external global %struct._SwiftEmptyArrayStorage, align 8
@".str.34.Goldilocks element must be 8 bytes" = private unnamed_addr constant [35 x i8] c"Goldilocks element must be 8 bytes\00"
@".str.32.non-canonical Goldilocks element" = private unnamed_addr constant [33 x i8] c"non-canonical Goldilocks element\00"
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAHc" = private constant i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAMc" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAHc" to i64)) to i32), section "__TEXT, __swift5_proto, regular", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAHc" = private constant i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAHc" to i64)) to i32), section "__TEXT, __swift5_proto, regular", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAHc" = private constant i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAMc" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAHc" to i64)) to i32), section "__TEXT, __swift5_proto, regular", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAHc" = private constant i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAHc" to i64)) to i32), section "__TEXT, __swift5_proto, regular", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAHc" = private constant i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAHc" to i64)) to i32), section "__TEXT, __swift5_proto, regular", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAHc" = private constant i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAMc" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAHc" to i64)) to i32), section "__TEXT, __swift5_proto, regular", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVHn" = private constant %swift.type_metadata_record { i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMn" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVHn" to i64)) to i32) }, section "__TEXT, __swift5_types, regular", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VHn" = private constant %swift.type_metadata_record { i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMn" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VHn" to i64)) to i32) }, section "__TEXT, __swift5_types, regular", no_sanitize_address, align 4
@"$s19SuperNeo_NuMetal_CT0aB5ErrorOHn" = private constant %swift.type_metadata_record { i32 trunc (i64 sub (i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMn" to i64), i64 ptrtoint (ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOHn" to i64)) to i32) }, section "__TEXT, __swift5_types, regular", no_sanitize_address, align 4
@__swift_reflection_version = linkonce_odr hidden constant i16 3
@llvm.used = appending global [86 x ptr] [ptr @"\01l__swift5_reflection_descriptor", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorO21__derived_enum_equalsySbAC_ACtFZ", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOHn", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMB", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMF", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMa", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMn", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorON", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAHc", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAAMc", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAHc", ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V10nonResidueAA0F5FieldVvau", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V10nonResidueAA0F5FieldVvgZ", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V10nonResidueAA0F5FieldVvpZ", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V17littleEndianBytesACs10ArraySliceVys5UInt8VG_tKcfC", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V17littleEndianBytesSays5UInt8VGvg", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V1moiyA2C_ACtFZ", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V1poiyA2C_ACtFZ", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V1soiyA2C_ACtFZ", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V1sopyA2CFZ", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V23__derived_struct_equalsySbAC_ACtFZ", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V2c0AA0F5FieldVvg", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V2c1AA0F5FieldVvg", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V3oneACvau", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V3oneACvgZ", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V3oneACvpZ", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V4hash4intoys6HasherVz_tF", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V4zeroACvau", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V4zeroACvgZ", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V4zeroACvpZ", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V6scaled2byAcA0F5FieldV_tF", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V7inverseACyKF", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V9hashValueSivg", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VHn", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMF", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMa", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMn", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VN", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAHc", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAAMc", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAHc", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAMc", ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VyAcA0F5FieldV_AEtcfC", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV14integerLiteralACs6UInt64V_tcfC", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV17littleEndianBytesACs10ArraySliceVys5UInt8VG_tKcfC", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV17littleEndianBytesSays5UInt8VGvg", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1moiyA2C_ACtFZ", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1poiyA2C_ACtFZ", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1soiyA2C_ACtFZ", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1sopyA2CFZ", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV23__derived_struct_equalsySbAC_ACtFZ", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3oneACvau", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3oneACvgZ", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3oneACvpZ", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3powyACs6UInt64VF", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV4hash4intoys6HasherVz_tF", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV4zeroACvau", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV4zeroACvgZ", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV4zeroACvpZ", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7inverseACyKF", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64Vvau", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvgZ", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZ", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7squaredACyF", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV8rawValues6UInt64Vvg", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV9hashValueSivg", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVHn", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMF", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMa", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMn", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVN", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAHc", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAAMc", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAHc", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAMc", ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVyACs6UInt64VcfC", ptr @__swift_reflection_version, ptr @"_swift_FORCE_LOAD_$_swiftCoreFoundation_$_SuperNeo_NuMetal_CT", ptr @"_swift_FORCE_LOAD_$_swiftDispatch_$_SuperNeo_NuMetal_CT", ptr @"_swift_FORCE_LOAD_$_swiftFoundation_$_SuperNeo_NuMetal_CT", ptr @"_swift_FORCE_LOAD_$_swiftIOKit_$_SuperNeo_NuMetal_CT", ptr @"_swift_FORCE_LOAD_$_swiftObjectiveC_$_SuperNeo_NuMetal_CT", ptr @"_swift_FORCE_LOAD_$_swiftXPC_$_SuperNeo_NuMetal_CT", ptr @"_swift_FORCE_LOAD_$_swift_Builtin_float_$_SuperNeo_NuMetal_CT"], section "llvm.metadata"

@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV8rawValues6UInt64VvpMV" = alias { i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV"
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV4zeroACvpZMV" = alias { i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV"
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3oneACvpZMV" = alias { i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV"
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV17littleEndianBytesSays5UInt8VGvpMV" = alias { i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV"
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV9hashValueSivpMV" = alias { i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV"
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V2c0AA0F5FieldVvpMV" = alias { i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV"
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V2c1AA0F5FieldVvpMV" = alias { i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV"
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V4zeroACvpZMV" = alias { i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV"
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V3oneACvpZMV" = alias { i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV"
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V10nonResidueAA0F5FieldVvpZMV" = alias { i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV"
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V17littleEndianBytesSays5UInt8VGvpMV" = alias { i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV"
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V9hashValueSivpMV" = alias { i32 }, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZMV"
@"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVN" = alias %swift.type, getelementptr inbounds (<{ ptr, ptr, i64, ptr, i32, [4 x i8] }>, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMf", i32 0, i32 2)
@"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VN" = alias %swift.type, getelementptr inbounds (<{ ptr, ptr, i64, ptr, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMf", i32 0, i32 2)
@"$s19SuperNeo_NuMetal_CT0aB5ErrorON" = alias %swift.type, getelementptr inbounds (<{ ptr, ptr, i64, ptr }>, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMf", i32 0, i32 2)

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc noundef nonnull ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64Vvau"() #0 {
entry:
  ret ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvpZ"
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc noundef i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7moduluss6UInt64VvgZ"() #0 {
entry:
  ret i64 -4294967295
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV8rawValues6UInt64Vvg"(i64 returned %0) #0 {
entry:
  ret i64 %0
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.usub.with.overflow.i64(i64, i64) #1

; Function Attrs: cold noreturn nounwind memory(inaccessiblemem: write)
declare void @llvm.trap() #2

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV14integerLiteralACs6UInt64V_tcfC"(i64 %0) #0 {
entry:
  %1 = icmp ult i64 %0, -4294967295
  %2 = tail call i64 @llvm.usub.sat.i64(i64 %0, i64 -4294967295)
  %3 = select i1 %1, i64 %0, i64 0
  %4 = or i64 %3, %2
  ret i64 %4
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc noundef nonnull ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV4zeroACvau"() #0 {
entry:
  ret ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV4zeroACvpZ"
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc noundef i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV4zeroACvgZ"() #0 {
entry:
  ret i64 0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc noundef nonnull ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3oneACvau"() #0 {
entry:
  ret ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3oneACvpZ"
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc noundef i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3oneACvgZ"() #0 {
entry:
  ret i64 1
}

define swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1poiyA2C_ACtFZ"(i64 %0, i64 %1) #3 {
entry:
  %2 = tail call swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1poiyA2C_ACtFZTf4nnd_n"(i64 %0, i64 %1) #25
  ret i64 %2
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1soiyA2C_ACtFZ"(i64 %0, i64 %1) #0 {
entry:
  %2 = tail call { i64, i1 } @llvm.usub.with.overflow.i64(i64 %0, i64 %1)
  %3 = extractvalue { i64, i1 } %2, 1
  %4 = extractvalue { i64, i1 } %2, 0
  %5 = select i1 %3, i64 -4294967295, i64 0
  %6 = add i64 %5, %4
  ret i64 %6
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1sopyA2CFZ"(i64 %0) #0 {
entry:
  %1 = tail call { i64, i1 } @llvm.usub.with.overflow.i64(i64 0, i64 %0)
  %2 = extractvalue { i64, i1 } %1, 1
  %3 = extractvalue { i64, i1 } %1, 0
  %4 = select i1 %2, i64 -4294967295, i64 0
  %5 = add i64 %4, %3
  ret i64 %5
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1moiyA2C_ACtFZ"(i64 %0, i64 %1) #0 {
entry:
  %2 = zext i64 %0 to i128
  %3 = zext i64 %1 to i128
  %4 = mul nuw i128 %3, %2
  %5 = trunc i128 %4 to i64
  %6 = lshr i128 %4, 64
  %7 = trunc nuw i128 %6 to i64
  %8 = lshr i64 %7, 32
  %9 = icmp ugt i64 %8, %5
  %.neg.i = select i1 %9, i64 -4294967295, i64 0
  %10 = sub i64 %5, %8
  %11 = add i64 %10, %.neg.i
  %12 = and i64 %7, 4294967295
  %13 = mul nuw i64 %12, 4294967295
  %14 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %11, i64 %13)
  %15 = extractvalue { i64, i1 } %14, 0
  %16 = extractvalue { i64, i1 } %14, 1
  %17 = select i1 %16, i64 4294967295, i64 0
  %18 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %15, i64 %17)
  %19 = extractvalue { i64, i1 } %18, 0
  %20 = extractvalue { i64, i1 } %18, 1
  %21 = select i1 %20, i64 4294967295, i64 0
  %22 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %19, i64 %21)
  %23 = extractvalue { i64, i1 } %22, 0
  %24 = extractvalue { i64, i1 } %22, 1
  %25 = select i1 %24, i64 4294967295, i64 0
  %26 = add i64 %25, %23
  %27 = icmp ult i64 %26, -4294967295
  %28 = tail call i64 @llvm.usub.sat.i64(i64 %26, i64 -4294967295)
  %29 = select i1 %27, i64 %26, i64 0
  %30 = or i64 %29, %28
  ret i64 %30
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7squaredACyF"(i64 %0) #0 {
entry:
  %1 = zext i64 %0 to i128
  %2 = mul nuw i128 %1, %1
  %3 = trunc i128 %2 to i64
  %4 = lshr i128 %2, 64
  %5 = trunc nuw i128 %4 to i64
  %6 = lshr i64 %5, 32
  %7 = icmp ugt i64 %6, %3
  %.neg.i = select i1 %7, i64 -4294967295, i64 0
  %8 = sub i64 %3, %6
  %9 = add i64 %8, %.neg.i
  %10 = and i64 %5, 4294967295
  %11 = mul nuw i64 %10, 4294967295
  %12 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %9, i64 %11)
  %13 = extractvalue { i64, i1 } %12, 0
  %14 = extractvalue { i64, i1 } %12, 1
  %15 = select i1 %14, i64 4294967295, i64 0
  %16 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %13, i64 %15)
  %17 = extractvalue { i64, i1 } %16, 0
  %18 = extractvalue { i64, i1 } %16, 1
  %19 = select i1 %18, i64 4294967295, i64 0
  %20 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %17, i64 %19)
  %21 = extractvalue { i64, i1 } %20, 0
  %22 = extractvalue { i64, i1 } %20, 1
  %23 = select i1 %22, i64 4294967295, i64 0
  %24 = add i64 %23, %21
  %25 = icmp ult i64 %24, -4294967295
  %26 = tail call i64 @llvm.usub.sat.i64(i64 %24, i64 -4294967295)
  %27 = select i1 %25, i64 %24, i64 0
  %28 = or i64 %27, %26
  ret i64 %28
}

; Function Attrs: nofree norecurse nosync nounwind memory(none)
define swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3powyACs6UInt64VF"(i64 %0, i64 %1) #4 {
entry:
  br label %.thread

.thread:                                          ; preds = %.thread, %entry
  %2 = phi i64 [ 1, %entry ], [ %37, %.thread ]
  %3 = phi i64 [ %1, %entry ], [ %64, %.thread ]
  %4 = phi i64 [ 0, %entry ], [ %5, %.thread ]
  %5 = add nuw nsw i64 %4, 1
  %6 = zext i64 %3 to i128
  %7 = lshr i64 %0, %4
  %.fr = freeze i64 %7
  %.5 = and i64 %.fr, 1
  %8 = icmp eq i64 %.5, 0
  %9 = zext i64 %2 to i128
  %10 = mul nuw i128 %6, %9
  %11 = trunc i128 %10 to i64
  %12 = lshr i128 %10, 64
  %13 = trunc nuw i128 %12 to i64
  %14 = lshr i64 %13, 32
  %15 = sub i64 %11, %14
  %16 = icmp ugt i64 %14, %11
  %.neg = select i1 %16, i64 -4294967295, i64 0
  %17 = add i64 %15, %.neg
  %18 = and i64 %13, 4294967295
  %19 = mul nuw i64 %18, 4294967295
  %20 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %17, i64 %19)
  %21 = extractvalue { i64, i1 } %20, 0
  %22 = extractvalue { i64, i1 } %20, 1
  %23 = select i1 %22, i64 4294967295, i64 0
  %24 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %21, i64 %23)
  %25 = extractvalue { i64, i1 } %24, 0
  %26 = extractvalue { i64, i1 } %24, 1
  %27 = select i1 %26, i64 4294967295, i64 0
  %28 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %25, i64 %27)
  %29 = extractvalue { i64, i1 } %28, 1
  %30 = select i1 %29, i64 4294967295, i64 0
  %31 = extractvalue { i64, i1 } %28, 0
  %32 = add i64 %30, %31
  %33 = icmp ult i64 %32, -4294967295
  %34 = select i1 %33, i64 %32, i64 0
  %35 = tail call i64 @llvm.usub.sat.i64(i64 %32, i64 -4294967295)
  %36 = or i64 %34, %35
  %37 = select i1 %8, i64 %2, i64 %36
  %38 = mul nuw i128 %6, %6
  %39 = lshr i128 %38, 64
  %40 = trunc nuw i128 %39 to i64
  %41 = lshr i64 %40, 32
  %42 = trunc i128 %38 to i64
  %43 = icmp ugt i64 %41, %42
  %.neg15 = select i1 %43, i64 -4294967295, i64 0
  %44 = sub i64 %42, %41
  %45 = add i64 %44, %.neg15
  %46 = and i64 %40, 4294967295
  %47 = mul nuw i64 %46, 4294967295
  %48 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %45, i64 %47)
  %49 = extractvalue { i64, i1 } %48, 0
  %50 = extractvalue { i64, i1 } %48, 1
  %51 = select i1 %50, i64 4294967295, i64 0
  %52 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %49, i64 %51)
  %53 = extractvalue { i64, i1 } %52, 0
  %54 = extractvalue { i64, i1 } %52, 1
  %55 = select i1 %54, i64 4294967295, i64 0
  %56 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %53, i64 %55)
  %57 = extractvalue { i64, i1 } %56, 0
  %58 = extractvalue { i64, i1 } %56, 1
  %59 = select i1 %58, i64 4294967295, i64 0
  %60 = add i64 %59, %57
  %61 = icmp ult i64 %60, -4294967295
  %62 = tail call i64 @llvm.usub.sat.i64(i64 %60, i64 -4294967295)
  %63 = select i1 %61, i64 %60, i64 0
  %64 = or i64 %63, %62
  %65 = icmp eq i64 %5, 64
  br i1 %65, label %66, label %.thread

66:                                               ; preds = %.thread
  ret i64 %37
}

; Function Attrs: nounwind
define swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV7inverseACyKF"(i64 %0, ptr readnone swiftself captures(none) %1, ptr noalias swifterror captures(none) dereferenceable(8) %2) #5 {
entry:
  %.not = icmp eq i64 %0, 0
  br i1 %.not, label %5, label %3

common.ret:                                       ; preds = %5, %3
  %common.ret.op = phi i64 [ %4, %3 ], [ undef, %5 ]
  ret i64 %common.ret.op

3:                                                ; preds = %entry
  %4 = tail call swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3powyACs6UInt64VF"(i64 -4294967297, i64 %0)
  br label %common.ret

5:                                                ; preds = %entry
  %6 = tail call ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOACs0F0AAWl"() #26
  %7 = tail call swiftcc { ptr, ptr } @swift_allocError(ptr nonnull getelementptr inbounds nuw (i8, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMf", i64 16), ptr %6, ptr null, i1 false) #10
  %8 = extractvalue { ptr, ptr } %7, 0
  %9 = extractvalue { ptr, ptr } %7, 1
  %10 = getelementptr inbounds nuw i8, ptr %9, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %9, i8 0, i64 16, i1 false)
  store i8 5, ptr %10, align 8
  store ptr %8, ptr %2, align 8
  tail call swiftcc void @swift_willThrow(ptr swiftself undef, ptr noalias nonnull readonly swifterror captures(none) dereferenceable(8) %2) #10
  store ptr %8, ptr %2, align 8
  br label %common.ret
}

; Function Attrs: sspreq
define swiftcc noundef ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV17littleEndianBytesSays5UInt8VGvg"(i64 %0) #6 {
entry:
  %1 = tail call ptr @__swift_instantiateConcreteTypeFromMangledNameV2(ptr nonnull @"$ss23_ContiguousArrayStorageCys5UInt8VGMd", ptr nonnull @"$ss23_ContiguousArrayStorageCys5UInt8VGMR") #27
  %2 = tail call noalias ptr @swift_allocObject(ptr %1, i64 40, i64 7) #10
  %call.i = tail call i64 @malloc_size(ptr noundef %2) #28, !clang.arc.no_objc_arc_exceptions !38
  %gepdiff = shl i64 %call.i, 1
  %3 = add i64 %gepdiff, -64
  %4 = getelementptr inbounds nuw i8, ptr %2, i64 16
  store i64 8, ptr %4, align 8
  %._storage1._capacityAndFlags = getelementptr inbounds nuw i8, ptr %2, i64 24
  store i64 %3, ptr %._storage1._capacityAndFlags, align 8
  %5 = getelementptr inbounds nuw i8, ptr %2, i64 32
  store i64 %0, ptr %5, align 1
  ret ptr %2
}

define swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV17littleEndianBytesACs10ArraySliceVys5UInt8VG_tKcfC"(ptr %0, ptr %1, i64 %2, i64 %3, ptr readnone swiftself captures(none) %4, ptr noalias swifterror captures(none) dereferenceable(8) %5) #3 {
entry:
  %6 = tail call swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV17littleEndianBytesACs10ArraySliceVys5UInt8VG_tKcfCTf4gXd_n"(ptr %1, i64 %2, i64 %3, ptr swiftself undef, ptr noalias nonnull swifterror captures(none) dereferenceable(8) %5) #25
  %7 = load ptr, ptr %5, align 8
  %.not = icmp eq ptr %7, null
  tail call void @swift_unknownObjectRelease(ptr %0) #10
  %. = select i1 %.not, i64 %6, i64 undef
  ret i64 %.
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc i1 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV23__derived_struct_equalsySbAC_ACtFZ"(i64 %0, i64 %1) #0 {
entry:
  %2 = icmp eq i64 %0, %1
  ret i1 %2
}

define swiftcc void @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV4hash4intoys6HasherVz_tF"(ptr captures(none) dereferenceable(72) %0, i64 %1) #3 {
entry:
  tail call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %1, ptr nonnull swiftself captures(none) dereferenceable(72) %0)
  ret void
}

define swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV9hashValueSivg"(i64 %0) #3 {
entry:
  %1 = alloca %Ts6HasherV, align 8
  call void @llvm.lifetime.start.p0(i64 72, ptr nonnull %1)
  call swiftcc void @"$ss6HasherV5_seedABSi_tcfC"(ptr noalias nonnull sret(%Ts6HasherV) captures(none) %1, i64 0)
  call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %0, ptr nonnull swiftself captures(none) dereferenceable(72) %1)
  %2 = call swiftcc i64 @"$ss6HasherV9_finalizeSiyF"(ptr nonnull swiftself captures(none) dereferenceable(72) %1)
  call void @llvm.lifetime.end.p0(i64 72, ptr nonnull %1)
  ret i64 %2
}

define linkonce_odr hidden swiftcc i1 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAASQ2eeoiySbx_xtFZTW"(ptr noalias captures(none) dereferenceable(8) %0, ptr noalias captures(none) dereferenceable(8) %1, ptr swiftself %2, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %3 = load i64, ptr %0, align 8
  %4 = load i64, ptr %1, align 8
  %5 = icmp eq i64 %3, %4
  ret i1 %5
}

define linkonce_odr hidden swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAASH9hashValueSivgTW"(ptr noalias swiftself captures(none) dereferenceable(8) %0, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %1 = alloca %Ts6HasherV, align 8
  %2 = load i64, ptr %0, align 8
  call void @llvm.lifetime.start.p0(i64 72, ptr nonnull %1)
  call swiftcc void @"$ss6HasherV5_seedABSi_tcfC"(ptr noalias nonnull sret(%Ts6HasherV) captures(none) %1, i64 0) #25
  call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %2, ptr nonnull swiftself captures(none) dereferenceable(72) %1) #25
  %3 = call swiftcc i64 @"$ss6HasherV9_finalizeSiyF"(ptr nonnull swiftself captures(none) dereferenceable(72) %1) #25
  call void @llvm.lifetime.end.p0(i64 72, ptr nonnull %1)
  ret i64 %3
}

define linkonce_odr hidden swiftcc void @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAASH4hash4intoys6HasherVz_tFTW"(ptr captures(none) dereferenceable(72) %0, ptr noalias swiftself captures(none) dereferenceable(8) %1, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %2 = load i64, ptr %1, align 8
  tail call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %2, ptr nonnull swiftself captures(none) dereferenceable(72) %0) #25
  ret void
}

define linkonce_odr hidden swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAASH13_rawHashValue4seedS2i_tFTW"(i64 %0, ptr noalias swiftself captures(none) dereferenceable(8) %1, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %2 = alloca %Ts6HasherV, align 8
  %3 = load i64, ptr %1, align 8
  call void @llvm.lifetime.start.p0(i64 72, ptr nonnull %2)
  call swiftcc void @"$ss6HasherV5_seedABSi_tcfC"(ptr noalias nonnull sret(%Ts6HasherV) captures(none) %2, i64 %0) #25
  call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %3, ptr nonnull swiftself captures(none) dereferenceable(72) %2) #25
  %4 = call swiftcc i64 @"$ss6HasherV9_finalizeSiyF"(ptr nonnull swiftself captures(none) dereferenceable(72) %2) #25
  call void @llvm.lifetime.end.p0(i64 72, ptr nonnull %2)
  ret i64 %4
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc i64 @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V2c0AA0F5FieldVvg"(i64 returned %0, i64 %1) #0 {
entry:
  ret i64 %0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc i64 @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V2c1AA0F5FieldVvg"(i64 %0, i64 returned %1) #0 {
entry:
  ret i64 %1
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc { i64, i64 } @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VyAcA0F5FieldV_AEtcfC"(i64 %0, i64 %1) #0 {
entry:
  %2 = insertvalue { i64, i64 } undef, i64 %0, 0
  %3 = insertvalue { i64, i64 } %2, i64 %1, 1
  ret { i64, i64 } %3
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc noundef nonnull ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V4zeroACvau"() #0 {
entry:
  ret ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V4zeroACvpZ"
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc { i64, i64 } @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V4zeroACvgZ"() #0 {
entry:
  ret { i64, i64 } zeroinitializer
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc noundef nonnull ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V3oneACvau"() #0 {
entry:
  ret ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V3oneACvpZ"
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc { i64, i64 } @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V3oneACvgZ"() #0 {
entry:
  ret { i64, i64 } { i64 1, i64 0 }
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc noundef nonnull ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V10nonResidueAA0F5FieldVvau"() #0 {
entry:
  ret ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V10nonResidueAA0F5FieldVvpZ"
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc noundef i64 @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V10nonResidueAA0F5FieldVvgZ"() #0 {
entry:
  ret i64 7
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc { i64, i64 } @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V1poiyA2C_ACtFZ"(i64 %0, i64 %1, i64 %2, i64 %3) #0 {
entry:
  %4 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %0, i64 %2)
  %5 = extractvalue { i64, i1 } %4, 0
  %6 = extractvalue { i64, i1 } %4, 1
  %7 = select i1 %6, i64 4294967295, i64 0
  %8 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %5, i64 %7)
  %9 = extractvalue { i64, i1 } %8, 0
  %10 = extractvalue { i64, i1 } %8, 1
  %11 = select i1 %10, i64 4294967295, i64 0
  %12 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %9, i64 %11)
  %13 = extractvalue { i64, i1 } %12, 0
  %14 = extractvalue { i64, i1 } %12, 1
  %15 = select i1 %14, i64 4294967295, i64 0
  %16 = add i64 %15, %13
  %17 = icmp ult i64 %16, -4294967295
  %18 = tail call i64 @llvm.usub.sat.i64(i64 %16, i64 -4294967295)
  %19 = select i1 %17, i64 %16, i64 0
  %20 = or i64 %19, %18
  %21 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %1, i64 %3)
  %22 = extractvalue { i64, i1 } %21, 0
  %23 = extractvalue { i64, i1 } %21, 1
  %24 = select i1 %23, i64 4294967295, i64 0
  %25 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %22, i64 %24)
  %26 = extractvalue { i64, i1 } %25, 0
  %27 = extractvalue { i64, i1 } %25, 1
  %28 = select i1 %27, i64 4294967295, i64 0
  %29 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %26, i64 %28)
  %30 = extractvalue { i64, i1 } %29, 0
  %31 = extractvalue { i64, i1 } %29, 1
  %32 = select i1 %31, i64 4294967295, i64 0
  %33 = add i64 %32, %30
  %34 = icmp ult i64 %33, -4294967295
  %35 = tail call i64 @llvm.usub.sat.i64(i64 %33, i64 -4294967295)
  %36 = select i1 %34, i64 %33, i64 0
  %37 = or i64 %36, %35
  %38 = insertvalue { i64, i64 } undef, i64 %20, 0
  %39 = insertvalue { i64, i64 } %38, i64 %37, 1
  ret { i64, i64 } %39
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc { i64, i64 } @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V1soiyA2C_ACtFZ"(i64 %0, i64 %1, i64 %2, i64 %3) #0 {
entry:
  %4 = tail call { i64, i1 } @llvm.usub.with.overflow.i64(i64 %1, i64 %3)
  %5 = extractvalue { i64, i1 } %4, 1
  %6 = extractvalue { i64, i1 } %4, 0
  %7 = tail call { i64, i1 } @llvm.usub.with.overflow.i64(i64 %0, i64 %2)
  %8 = extractvalue { i64, i1 } %7, 1
  %9 = select i1 %8, i64 -4294967295, i64 0
  %10 = extractvalue { i64, i1 } %7, 0
  %11 = add i64 %9, %10
  %12 = select i1 %5, i64 -4294967295, i64 0
  %13 = add i64 %12, %6
  %14 = insertvalue { i64, i64 } undef, i64 %11, 0
  %15 = insertvalue { i64, i64 } %14, i64 %13, 1
  ret { i64, i64 } %15
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc { i64, i64 } @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V1sopyA2CFZ"(i64 %0, i64 %1) #0 {
entry:
  %2 = tail call { i64, i1 } @llvm.usub.with.overflow.i64(i64 0, i64 %1)
  %3 = extractvalue { i64, i1 } %2, 1
  %4 = extractvalue { i64, i1 } %2, 0
  %5 = tail call { i64, i1 } @llvm.usub.with.overflow.i64(i64 0, i64 %0)
  %6 = extractvalue { i64, i1 } %5, 1
  %7 = select i1 %6, i64 -4294967295, i64 0
  %8 = extractvalue { i64, i1 } %5, 0
  %9 = add i64 %7, %8
  %10 = select i1 %3, i64 -4294967295, i64 0
  %11 = add i64 %10, %4
  %12 = insertvalue { i64, i64 } undef, i64 %9, 0
  %13 = insertvalue { i64, i64 } %12, i64 %11, 1
  ret { i64, i64 } %13
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc { i64, i64 } @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V1moiyA2C_ACtFZ"(i64 %0, i64 %1, i64 %2, i64 %3) #0 {
entry:
  %4 = zext i64 %0 to i128
  %5 = zext i64 %2 to i128
  %6 = mul nuw i128 %5, %4
  %7 = trunc i128 %6 to i64
  %8 = lshr i128 %6, 64
  %9 = trunc nuw i128 %8 to i64
  %10 = lshr i64 %9, 32
  %11 = icmp ugt i64 %10, %7
  %.neg.i = select i1 %11, i64 -4294967295, i64 0
  %12 = sub i64 %7, %10
  %13 = add i64 %12, %.neg.i
  %14 = and i64 %9, 4294967295
  %15 = mul nuw i64 %14, 4294967295
  %16 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %13, i64 %15)
  %17 = extractvalue { i64, i1 } %16, 0
  %18 = extractvalue { i64, i1 } %16, 1
  %19 = select i1 %18, i64 4294967295, i64 0
  %20 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %17, i64 %19)
  %21 = extractvalue { i64, i1 } %20, 0
  %22 = extractvalue { i64, i1 } %20, 1
  %23 = select i1 %22, i64 4294967295, i64 0
  %24 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %21, i64 %23)
  %25 = extractvalue { i64, i1 } %24, 0
  %26 = extractvalue { i64, i1 } %24, 1
  %27 = select i1 %26, i64 4294967295, i64 0
  %28 = add i64 %27, %25
  %29 = icmp ult i64 %28, -4294967295
  %30 = tail call i64 @llvm.usub.sat.i64(i64 %28, i64 -4294967295)
  %31 = select i1 %29, i64 %28, i64 0
  %32 = or i64 %31, %30
  %33 = zext i64 %1 to i128
  %34 = zext i64 %3 to i128
  %35 = mul nuw i128 %34, %33
  %36 = trunc i128 %35 to i64
  %37 = lshr i128 %35, 64
  %38 = trunc nuw i128 %37 to i64
  %39 = lshr i64 %38, 32
  %40 = icmp ugt i64 %39, %36
  %.neg.i2 = select i1 %40, i64 -4294967295, i64 0
  %41 = sub i64 %36, %39
  %42 = add i64 %41, %.neg.i2
  %43 = and i64 %38, 4294967295
  %44 = mul nuw i64 %43, 4294967295
  %45 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %42, i64 %44)
  %46 = extractvalue { i64, i1 } %45, 0
  %47 = extractvalue { i64, i1 } %45, 1
  %48 = select i1 %47, i64 4294967295, i64 0
  %49 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %46, i64 %48)
  %50 = extractvalue { i64, i1 } %49, 0
  %51 = extractvalue { i64, i1 } %49, 1
  %52 = select i1 %51, i64 4294967295, i64 0
  %53 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %50, i64 %52)
  %54 = extractvalue { i64, i1 } %53, 0
  %55 = extractvalue { i64, i1 } %53, 1
  %56 = select i1 %55, i64 4294967295, i64 0
  %57 = add i64 %56, %54
  %58 = icmp ult i64 %57, -4294967295
  %59 = tail call i64 @llvm.usub.sat.i64(i64 %57, i64 -4294967295)
  %60 = select i1 %58, i64 %57, i64 0
  %61 = or i64 %60, %59
  %62 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %0, i64 %1)
  %63 = extractvalue { i64, i1 } %62, 0
  %64 = extractvalue { i64, i1 } %62, 1
  %65 = select i1 %64, i64 4294967295, i64 0
  %66 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %63, i64 %65)
  %67 = extractvalue { i64, i1 } %66, 0
  %68 = extractvalue { i64, i1 } %66, 1
  %69 = select i1 %68, i64 4294967295, i64 0
  %70 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %67, i64 %69)
  %71 = extractvalue { i64, i1 } %70, 0
  %72 = extractvalue { i64, i1 } %70, 1
  %73 = select i1 %72, i64 4294967295, i64 0
  %74 = add i64 %73, %71
  %75 = icmp ult i64 %74, -4294967295
  %76 = tail call i64 @llvm.usub.sat.i64(i64 %74, i64 -4294967295)
  %77 = select i1 %75, i64 %74, i64 0
  %78 = or i64 %77, %76
  %79 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %2, i64 %3)
  %80 = extractvalue { i64, i1 } %79, 0
  %81 = extractvalue { i64, i1 } %79, 1
  %82 = select i1 %81, i64 4294967295, i64 0
  %83 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %80, i64 %82)
  %84 = extractvalue { i64, i1 } %83, 0
  %85 = extractvalue { i64, i1 } %83, 1
  %86 = select i1 %85, i64 4294967295, i64 0
  %87 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %84, i64 %86)
  %88 = extractvalue { i64, i1 } %87, 0
  %89 = extractvalue { i64, i1 } %87, 1
  %90 = select i1 %89, i64 4294967295, i64 0
  %91 = add i64 %90, %88
  %92 = icmp ult i64 %91, -4294967295
  %93 = tail call i64 @llvm.usub.sat.i64(i64 %91, i64 -4294967295)
  %94 = select i1 %92, i64 %91, i64 0
  %95 = or i64 %94, %93
  %96 = zext i64 %78 to i128
  %97 = zext i64 %95 to i128
  %98 = mul nuw i128 %97, %96
  %99 = trunc i128 %98 to i64
  %100 = lshr i128 %98, 64
  %101 = trunc nuw i128 %100 to i64
  %102 = lshr i64 %101, 32
  %103 = icmp ugt i64 %102, %99
  %.neg.i3 = select i1 %103, i64 -4294967295, i64 0
  %104 = sub i64 %99, %102
  %105 = add i64 %104, %.neg.i3
  %106 = and i64 %101, 4294967295
  %107 = mul nuw i64 %106, 4294967295
  %108 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %105, i64 %107)
  %109 = extractvalue { i64, i1 } %108, 0
  %110 = extractvalue { i64, i1 } %108, 1
  %111 = select i1 %110, i64 4294967295, i64 0
  %112 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %109, i64 %111)
  %113 = extractvalue { i64, i1 } %112, 0
  %114 = extractvalue { i64, i1 } %112, 1
  %115 = select i1 %114, i64 4294967295, i64 0
  %116 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %113, i64 %115)
  %117 = extractvalue { i64, i1 } %116, 0
  %118 = extractvalue { i64, i1 } %116, 1
  %119 = select i1 %118, i64 4294967295, i64 0
  %120 = add i64 %119, %117
  %121 = icmp ult i64 %120, -4294967295
  %122 = tail call i64 @llvm.usub.sat.i64(i64 %120, i64 -4294967295)
  %123 = select i1 %121, i64 %120, i64 0
  %124 = or i64 %123, %122
  %125 = tail call { i64, i1 } @llvm.usub.with.overflow.i64(i64 %124, i64 %32)
  %126 = extractvalue { i64, i1 } %125, 0
  %127 = extractvalue { i64, i1 } %125, 1
  %128 = select i1 %127, i64 -4294967295, i64 0
  %129 = add i64 %128, %126
  %130 = tail call { i64, i1 } @llvm.usub.with.overflow.i64(i64 %129, i64 %61)
  %131 = extractvalue { i64, i1 } %130, 1
  %132 = extractvalue { i64, i1 } %130, 0
  %133 = select i1 %131, i64 -4294967295, i64 0
  %134 = add i64 %133, %132
  %135 = zext i64 %61 to i128
  %136 = mul nuw nsw i128 %135, 7
  %137 = trunc i128 %136 to i64
  %138 = lshr i128 %136, 64
  %139 = trunc nuw nsw i128 %138 to i64
  %140 = mul nuw nsw i64 %139, 4294967295
  %141 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %137, i64 %140)
  %142 = extractvalue { i64, i1 } %141, 0
  %143 = extractvalue { i64, i1 } %141, 1
  %144 = select i1 %143, i64 4294967295, i64 0
  %145 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %142, i64 %144)
  %146 = extractvalue { i64, i1 } %145, 0
  %147 = extractvalue { i64, i1 } %145, 1
  %148 = select i1 %147, i64 4294967295, i64 0
  %149 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %146, i64 %148)
  %150 = extractvalue { i64, i1 } %149, 0
  %151 = extractvalue { i64, i1 } %149, 1
  %152 = select i1 %151, i64 4294967295, i64 0
  %153 = add i64 %152, %150
  %154 = icmp ult i64 %153, -4294967295
  %155 = tail call i64 @llvm.usub.sat.i64(i64 %153, i64 -4294967295)
  %156 = select i1 %154, i64 %153, i64 0
  %157 = or i64 %156, %155
  %158 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %32, i64 %157)
  %159 = extractvalue { i64, i1 } %158, 0
  %160 = extractvalue { i64, i1 } %158, 1
  %161 = select i1 %160, i64 4294967295, i64 0
  %162 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %159, i64 %161)
  %163 = extractvalue { i64, i1 } %162, 0
  %164 = extractvalue { i64, i1 } %162, 1
  %165 = select i1 %164, i64 4294967295, i64 0
  %166 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %163, i64 %165)
  %167 = extractvalue { i64, i1 } %166, 0
  %168 = extractvalue { i64, i1 } %166, 1
  %169 = select i1 %168, i64 4294967295, i64 0
  %170 = add i64 %169, %167
  %171 = icmp ult i64 %170, -4294967295
  %172 = tail call i64 @llvm.usub.sat.i64(i64 %170, i64 -4294967295)
  %173 = select i1 %171, i64 %170, i64 0
  %174 = or i64 %173, %172
  %175 = insertvalue { i64, i64 } undef, i64 %174, 0
  %176 = insertvalue { i64, i64 } %175, i64 %134, 1
  ret { i64, i64 } %176
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc { i64, i64 } @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V6scaled2byAcA0F5FieldV_tF"(i64 %0, i64 %1, i64 %2) #0 {
entry:
  %3 = zext i64 %1 to i128
  %4 = zext i64 %0 to i128
  %5 = mul nuw i128 %3, %4
  %6 = trunc i128 %5 to i64
  %7 = lshr i128 %5, 64
  %8 = trunc nuw i128 %7 to i64
  %9 = lshr i64 %8, 32
  %10 = icmp ugt i64 %9, %6
  %.neg.i = select i1 %10, i64 -4294967295, i64 0
  %11 = sub i64 %6, %9
  %12 = add i64 %11, %.neg.i
  %13 = and i64 %8, 4294967295
  %14 = mul nuw i64 %13, 4294967295
  %15 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %12, i64 %14)
  %16 = extractvalue { i64, i1 } %15, 0
  %17 = extractvalue { i64, i1 } %15, 1
  %18 = select i1 %17, i64 4294967295, i64 0
  %19 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %16, i64 %18)
  %20 = extractvalue { i64, i1 } %19, 0
  %21 = extractvalue { i64, i1 } %19, 1
  %22 = select i1 %21, i64 4294967295, i64 0
  %23 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %20, i64 %22)
  %24 = extractvalue { i64, i1 } %23, 0
  %25 = extractvalue { i64, i1 } %23, 1
  %26 = select i1 %25, i64 4294967295, i64 0
  %27 = add i64 %26, %24
  %28 = icmp ult i64 %27, -4294967295
  %29 = tail call i64 @llvm.usub.sat.i64(i64 %27, i64 -4294967295)
  %30 = select i1 %28, i64 %27, i64 0
  %31 = or i64 %30, %29
  %32 = zext i64 %2 to i128
  %33 = mul nuw i128 %32, %4
  %34 = trunc i128 %33 to i64
  %35 = lshr i128 %33, 64
  %36 = trunc nuw i128 %35 to i64
  %37 = lshr i64 %36, 32
  %38 = icmp ugt i64 %37, %34
  %.neg.i1 = select i1 %38, i64 -4294967295, i64 0
  %39 = sub i64 %34, %37
  %40 = add i64 %39, %.neg.i1
  %41 = and i64 %36, 4294967295
  %42 = mul nuw i64 %41, 4294967295
  %43 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %40, i64 %42)
  %44 = extractvalue { i64, i1 } %43, 0
  %45 = extractvalue { i64, i1 } %43, 1
  %46 = select i1 %45, i64 4294967295, i64 0
  %47 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %44, i64 %46)
  %48 = extractvalue { i64, i1 } %47, 0
  %49 = extractvalue { i64, i1 } %47, 1
  %50 = select i1 %49, i64 4294967295, i64 0
  %51 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %48, i64 %50)
  %52 = extractvalue { i64, i1 } %51, 0
  %53 = extractvalue { i64, i1 } %51, 1
  %54 = select i1 %53, i64 4294967295, i64 0
  %55 = add i64 %54, %52
  %56 = icmp ult i64 %55, -4294967295
  %57 = tail call i64 @llvm.usub.sat.i64(i64 %55, i64 -4294967295)
  %58 = select i1 %56, i64 %55, i64 0
  %59 = or i64 %58, %57
  %60 = insertvalue { i64, i64 } undef, i64 %31, 0
  %61 = insertvalue { i64, i64 } %60, i64 %59, 1
  ret { i64, i64 } %61
}

; Function Attrs: nounwind
define swiftcc { i64, i64 } @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V7inverseACyKF"(i64 %0, i64 %1, ptr readnone swiftself captures(none) %2, ptr noalias swifterror captures(none) dereferenceable(8) %3) #5 {
entry:
  %4 = zext i64 %0 to i128
  %5 = mul nuw i128 %4, %4
  %6 = trunc i128 %5 to i64
  %7 = lshr i128 %5, 64
  %8 = trunc nuw i128 %7 to i64
  %9 = lshr i64 %8, 32
  %10 = icmp ugt i64 %9, %6
  %.neg.i = select i1 %10, i64 -4294967295, i64 0
  %11 = sub i64 %6, %9
  %12 = add i64 %11, %.neg.i
  %13 = and i64 %8, 4294967295
  %14 = mul nuw i64 %13, 4294967295
  %15 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %12, i64 %14)
  %16 = extractvalue { i64, i1 } %15, 0
  %17 = extractvalue { i64, i1 } %15, 1
  %18 = select i1 %17, i64 4294967295, i64 0
  %19 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %16, i64 %18)
  %20 = extractvalue { i64, i1 } %19, 0
  %21 = extractvalue { i64, i1 } %19, 1
  %22 = select i1 %21, i64 4294967295, i64 0
  %23 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %20, i64 %22)
  %24 = extractvalue { i64, i1 } %23, 0
  %25 = extractvalue { i64, i1 } %23, 1
  %26 = select i1 %25, i64 4294967295, i64 0
  %27 = add i64 %26, %24
  %28 = icmp ult i64 %27, -4294967295
  %29 = tail call i64 @llvm.usub.sat.i64(i64 %27, i64 -4294967295)
  %30 = select i1 %28, i64 %27, i64 0
  %31 = or i64 %30, %29
  %32 = zext i64 %1 to i128
  %33 = mul nuw i128 %32, %32
  %34 = trunc i128 %33 to i64
  %35 = lshr i128 %33, 64
  %36 = trunc nuw i128 %35 to i64
  %37 = lshr i64 %36, 32
  %38 = icmp ugt i64 %37, %34
  %.neg.i2 = select i1 %38, i64 -4294967295, i64 0
  %39 = sub i64 %34, %37
  %40 = add i64 %39, %.neg.i2
  %41 = and i64 %36, 4294967295
  %42 = mul nuw i64 %41, 4294967295
  %43 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %40, i64 %42)
  %44 = extractvalue { i64, i1 } %43, 0
  %45 = extractvalue { i64, i1 } %43, 1
  %46 = select i1 %45, i64 4294967295, i64 0
  %47 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %44, i64 %46)
  %48 = extractvalue { i64, i1 } %47, 0
  %49 = extractvalue { i64, i1 } %47, 1
  %50 = select i1 %49, i64 4294967295, i64 0
  %51 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %48, i64 %50)
  %52 = extractvalue { i64, i1 } %51, 0
  %53 = extractvalue { i64, i1 } %51, 1
  %54 = select i1 %53, i64 4294967295, i64 0
  %55 = add i64 %54, %52
  %56 = icmp ult i64 %55, -4294967295
  %57 = tail call i64 @llvm.usub.sat.i64(i64 %55, i64 -4294967295)
  %58 = select i1 %56, i64 %55, i64 0
  %59 = or i64 %58, %57
  %60 = zext i64 %59 to i128
  %61 = mul nuw nsw i128 %60, 7
  %62 = trunc i128 %61 to i64
  %63 = lshr i128 %61, 64
  %64 = trunc nuw nsw i128 %63 to i64
  %65 = mul nuw nsw i64 %64, 4294967295
  %66 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %62, i64 %65)
  %67 = extractvalue { i64, i1 } %66, 0
  %68 = extractvalue { i64, i1 } %66, 1
  %69 = select i1 %68, i64 4294967295, i64 0
  %70 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %67, i64 %69)
  %71 = extractvalue { i64, i1 } %70, 0
  %72 = extractvalue { i64, i1 } %70, 1
  %73 = select i1 %72, i64 4294967295, i64 0
  %74 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %71, i64 %73)
  %75 = extractvalue { i64, i1 } %74, 0
  %76 = extractvalue { i64, i1 } %74, 1
  %77 = select i1 %76, i64 4294967295, i64 0
  %78 = add i64 %77, %75
  %79 = icmp ult i64 %78, -4294967295
  %80 = tail call i64 @llvm.usub.sat.i64(i64 %78, i64 -4294967295)
  %81 = select i1 %79, i64 %78, i64 0
  %82 = or i64 %81, %80
  %83 = tail call { i64, i1 } @llvm.usub.with.overflow.i64(i64 %31, i64 %82)
  %84 = extractvalue { i64, i1 } %83, 1
  %85 = extractvalue { i64, i1 } %83, 0
  %86 = select i1 %84, i64 -4294967295, i64 0
  %87 = add i64 %86, %85
  %.not = icmp eq i64 %87, 0
  br i1 %.not, label %153, label %88

88:                                               ; preds = %entry
  %89 = tail call swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV3powyACs6UInt64VF"(i64 -4294967297, i64 %87)
  %90 = zext i64 %89 to i128
  %91 = mul nuw i128 %90, %4
  %92 = trunc i128 %91 to i64
  %93 = lshr i128 %91, 64
  %94 = trunc nuw i128 %93 to i64
  %95 = lshr i64 %94, 32
  %96 = icmp ugt i64 %95, %92
  %.neg.i4 = select i1 %96, i64 -4294967295, i64 0
  %97 = sub i64 %92, %95
  %98 = add i64 %97, %.neg.i4
  %99 = and i64 %94, 4294967295
  %100 = mul nuw i64 %99, 4294967295
  %101 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %98, i64 %100)
  %102 = extractvalue { i64, i1 } %101, 0
  %103 = extractvalue { i64, i1 } %101, 1
  %104 = select i1 %103, i64 4294967295, i64 0
  %105 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %102, i64 %104)
  %106 = extractvalue { i64, i1 } %105, 0
  %107 = extractvalue { i64, i1 } %105, 1
  %108 = select i1 %107, i64 4294967295, i64 0
  %109 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %106, i64 %108)
  %110 = extractvalue { i64, i1 } %109, 0
  %111 = extractvalue { i64, i1 } %109, 1
  %112 = select i1 %111, i64 4294967295, i64 0
  %113 = add i64 %112, %110
  %114 = icmp ult i64 %113, -4294967295
  %115 = tail call i64 @llvm.usub.sat.i64(i64 %113, i64 -4294967295)
  %116 = select i1 %114, i64 %113, i64 0
  %117 = or i64 %116, %115
  %118 = tail call { i64, i1 } @llvm.usub.with.overflow.i64(i64 0, i64 %1)
  %119 = extractvalue { i64, i1 } %118, 1
  %120 = extractvalue { i64, i1 } %118, 0
  %121 = select i1 %119, i64 -4294967295, i64 0
  %122 = add i64 %121, %120
  %123 = zext i64 %122 to i128
  %124 = mul nuw i128 %90, %123
  %125 = trunc i128 %124 to i64
  %126 = lshr i128 %124, 64
  %127 = trunc nuw i128 %126 to i64
  %128 = lshr i64 %127, 32
  %129 = icmp ugt i64 %128, %125
  %.neg.i5 = select i1 %129, i64 -4294967295, i64 0
  %130 = sub i64 %125, %128
  %131 = add i64 %130, %.neg.i5
  %132 = and i64 %127, 4294967295
  %133 = mul nuw i64 %132, 4294967295
  %134 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %131, i64 %133)
  %135 = extractvalue { i64, i1 } %134, 0
  %136 = extractvalue { i64, i1 } %134, 1
  %137 = select i1 %136, i64 4294967295, i64 0
  %138 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %135, i64 %137)
  %139 = extractvalue { i64, i1 } %138, 0
  %140 = extractvalue { i64, i1 } %138, 1
  %141 = select i1 %140, i64 4294967295, i64 0
  %142 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %139, i64 %141)
  %143 = extractvalue { i64, i1 } %142, 0
  %144 = extractvalue { i64, i1 } %142, 1
  %145 = select i1 %144, i64 4294967295, i64 0
  %146 = add i64 %145, %143
  %147 = icmp ult i64 %146, -4294967295
  %148 = tail call i64 @llvm.usub.sat.i64(i64 %146, i64 -4294967295)
  %149 = select i1 %147, i64 %146, i64 0
  %150 = or i64 %149, %148
  %151 = insertvalue { i64, i64 } undef, i64 %117, 0
  %152 = insertvalue { i64, i64 } %151, i64 %150, 1
  br label %common.ret

common.ret:                                       ; preds = %88, %153
  %common.ret.op = phi { i64, i64 } [ undef, %153 ], [ %152, %88 ]
  ret { i64, i64 } %common.ret.op

153:                                              ; preds = %entry
  %154 = tail call ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOACs0F0AAWl"() #26
  %155 = tail call swiftcc { ptr, ptr } @swift_allocError(ptr nonnull getelementptr inbounds nuw (i8, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMf", i64 16), ptr %154, ptr null, i1 false) #10
  %156 = extractvalue { ptr, ptr } %155, 0
  %157 = extractvalue { ptr, ptr } %155, 1
  %158 = getelementptr inbounds nuw i8, ptr %157, i64 16
  tail call void @llvm.memset.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %157, i8 0, i64 16, i1 false)
  store i8 5, ptr %158, align 8
  store ptr %156, ptr %3, align 8
  tail call swiftcc void @swift_willThrow(ptr swiftself undef, ptr noalias nonnull readonly swifterror captures(none) dereferenceable(8) %3) #10
  store ptr %156, ptr %3, align 8
  br label %common.ret
}

; Function Attrs: sspreq
define swiftcc ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V17littleEndianBytesSays5UInt8VGvg"(i64 %0, i64 %1) #6 {
entry:
  %2 = alloca %TSa, align 8
  %3 = tail call ptr @__swift_instantiateConcreteTypeFromMangledNameV2(ptr nonnull @"$ss23_ContiguousArrayStorageCys5UInt8VGMd", ptr nonnull @"$ss23_ContiguousArrayStorageCys5UInt8VGMR") #27
  %4 = tail call noalias ptr @swift_allocObject(ptr %3, i64 40, i64 7) #10
  %call.i = tail call i64 @malloc_size(ptr noundef %4) #28, !clang.arc.no_objc_arc_exceptions !38
  %gepdiff = shl i64 %call.i, 1
  %5 = add i64 %gepdiff, -64
  %6 = getelementptr inbounds nuw i8, ptr %4, i64 16
  store i64 8, ptr %6, align 8
  %._storage5._capacityAndFlags = getelementptr inbounds nuw i8, ptr %4, i64 24
  store i64 %5, ptr %._storage5._capacityAndFlags, align 8
  %7 = getelementptr inbounds nuw i8, ptr %4, i64 32
  store i64 %0, ptr %7, align 1
  %8 = tail call noalias ptr @swift_allocObject(ptr %3, i64 40, i64 7) #10
  %call.i7 = tail call i64 @malloc_size(ptr noundef %8) #28, !clang.arc.no_objc_arc_exceptions !38
  %gepdiff6 = shl i64 %call.i7, 1
  %9 = add i64 %gepdiff6, -64
  %10 = getelementptr inbounds nuw i8, ptr %8, i64 16
  store i64 8, ptr %10, align 8
  %._storage4._capacityAndFlags = getelementptr inbounds nuw i8, ptr %8, i64 24
  store i64 %9, ptr %._storage4._capacityAndFlags, align 8
  %11 = getelementptr inbounds nuw i8, ptr %8, i64 32
  store i64 %1, ptr %11, align 1
  call void @llvm.lifetime.start.p0(i64 8, ptr nonnull %2)
  store ptr %4, ptr %2, align 8
  call swiftcc void @"$sSa6append10contentsOfyqd__n_t7ElementQyd__RszSTRd__lFs5UInt8V_SayAFGTg5"(ptr %8, ptr nonnull swiftself captures(none) dereferenceable(8) %2)
  %12 = load ptr, ptr %2, align 8
  call void @llvm.lifetime.end.p0(i64 8, ptr nonnull %2)
  ret ptr %12
}

define swiftcc { i64, i64 } @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V17littleEndianBytesACs10ArraySliceVys5UInt8VG_tKcfC"(ptr %0, ptr %1, i64 %2, i64 %3, ptr readnone swiftself captures(none) %4, ptr noalias swifterror captures(none) dereferenceable(8) %5) #3 {
entry:
  %6 = lshr i64 %3, 1
  %7 = tail call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %6, i64 %2)
  %8 = extractvalue { i64, i1 } %7, 1
  br i1 %8, label %51, label %9, !prof !39

9:                                                ; preds = %entry
  %10 = extractvalue { i64, i1 } %7, 0
  %11 = icmp eq i64 %10, 16
  br i1 %11, label %24, label %41

12:                                               ; preds = %28
  %13 = icmp slt i64 %6, %2
  br i1 %13, label %54, label %14, !prof !39

14:                                               ; preds = %12
  %15 = icmp slt i64 %6, %26
  br i1 %15, label %55, label %16, !prof !39

16:                                               ; preds = %14
  %17 = icmp slt i64 %26, 0
  br i1 %17, label %56, label %18, !prof !39

18:                                               ; preds = %16
  %19 = and i64 %3, 1
  %20 = shl nuw i64 %26, 1
  %21 = or disjoint i64 %20, %19
  %22 = tail call swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV17littleEndianBytesACs10ArraySliceVys5UInt8VG_tKcfCTf4gXd_n"(ptr %1, i64 %2, i64 %21, ptr swiftself undef, ptr noalias nonnull swifterror captures(none) dereferenceable(8) %5)
  %23 = load ptr, ptr %5, align 8
  %.not = icmp eq ptr %23, null
  br i1 %.not, label %30, label %.sink.split

24:                                               ; preds = %9
  %25 = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %2, i64 8)
  %26 = extractvalue { i64, i1 } %25, 0
  %27 = extractvalue { i64, i1 } %25, 1
  br i1 %27, label %52, label %28, !prof !39

28:                                               ; preds = %24
  %29 = icmp slt i64 %26, %2
  br i1 %29, label %53, label %12, !prof !39

30:                                               ; preds = %18
  %31 = tail call swiftcc { ptr, ptr, i64, i64 } @"$sSKsE6suffixy11SubSequenceQzSiFs10ArraySliceVys5UInt8VG_Tg5"(i64 8, ptr %0, ptr %1, i64 %2, i64 %3)
  %32 = extractvalue { ptr, ptr, i64, i64 } %31, 0
  %33 = extractvalue { ptr, ptr, i64, i64 } %31, 1
  %34 = extractvalue { ptr, ptr, i64, i64 } %31, 2
  %35 = extractvalue { ptr, ptr, i64, i64 } %31, 3
  %36 = tail call swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV17littleEndianBytesACs10ArraySliceVys5UInt8VG_tKcfCTf4gXd_n"(ptr %33, i64 %34, i64 %35, ptr swiftself undef, ptr noalias nonnull swifterror captures(none) dereferenceable(8) %5)
  %37 = load ptr, ptr %5, align 8
  %.not5 = icmp eq ptr %37, null
  tail call void @swift_unknownObjectRelease(ptr %32) #10
  br i1 %.not5, label %38, label %49

common.ret:                                       ; preds = %49, %38
  %common.ret.op = phi { i64, i64 } [ %40, %38 ], [ undef, %49 ]
  ret { i64, i64 } %common.ret.op

38:                                               ; preds = %30
  %39 = insertvalue { i64, i64 } undef, i64 %22, 0
  %40 = insertvalue { i64, i64 } %39, i64 %36, 1
  br label %common.ret

41:                                               ; preds = %9
  %42 = or i64 sub (i64 ptrtoint (ptr @".str.39.GoldilocksExt2 element must be 16 bytes" to i64), i64 32), -9223372036854775808
  %43 = tail call ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOACs0F0AAWl"() #26
  %44 = tail call swiftcc { ptr, ptr } @swift_allocError(ptr nonnull getelementptr inbounds nuw (i8, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMf", i64 16), ptr %43, ptr null, i1 false) #10
  %45 = extractvalue { ptr, ptr } %44, 0
  %46 = extractvalue { ptr, ptr } %44, 1
  store i64 -3458764513820540889, ptr %46, align 8
  %47 = getelementptr inbounds nuw i8, ptr %46, i64 8
  store i64 %42, ptr %47, align 8
  %48 = getelementptr inbounds nuw i8, ptr %46, i64 16
  store i8 0, ptr %48, align 8
  store ptr %45, ptr %5, align 8
  tail call swiftcc void @swift_willThrow(ptr swiftself undef, ptr noalias nonnull readonly swifterror captures(none) dereferenceable(8) %5) #10
  br label %.sink.split

.sink.split:                                      ; preds = %18, %41
  %.ph = phi ptr [ %45, %41 ], [ %23, %18 ]
  tail call void @swift_unknownObjectRelease(ptr %0) #10
  br label %49

49:                                               ; preds = %.sink.split, %30
  %50 = phi ptr [ %37, %30 ], [ %.ph, %.sink.split ]
  store ptr %50, ptr %5, align 8
  br label %common.ret

51:                                               ; preds = %entry
  tail call void asm sideeffect "", "n"(i32 0) #10
  tail call void @llvm.trap()
  unreachable

52:                                               ; preds = %24
  tail call void asm sideeffect "", "n"(i32 1) #10
  tail call void @llvm.trap()
  unreachable

53:                                               ; preds = %28
  tail call void asm sideeffect "", "n"(i32 2) #10
  tail call void @llvm.trap()
  unreachable

54:                                               ; preds = %12
  tail call void asm sideeffect "", "n"(i32 3) #10
  tail call void @llvm.trap()
  unreachable

55:                                               ; preds = %14
  tail call void asm sideeffect "", "n"(i32 4) #10
  tail call void @llvm.trap()
  unreachable

56:                                               ; preds = %16
  tail call void asm sideeffect "", "n"(i32 5) #10
  tail call void @llvm.trap()
  unreachable
}

define linkonce_odr hidden swiftcc { ptr, ptr, i64, i64 } @"$sSKsE6suffixy11SubSequenceQzSiFs10ArraySliceVys5UInt8VG_Tg5"(i64 %0, ptr %1, ptr %2, i64 %3, i64 %4) local_unnamed_addr #3 {
entry:
  %5 = icmp slt i64 %0, 0
  br i1 %5, label %25, label %6, !prof !39

6:                                                ; preds = %entry
  %7 = lshr i64 %4, 1
  %8 = tail call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %3, i64 %7)
  %9 = extractvalue { i64, i1 } %8, 1
  br i1 %9, label %26, label %10, !prof !39

10:                                               ; preds = %6
  %11 = extractvalue { i64, i1 } %8, 0
  %12 = sub nsw i64 0, %0
  %13 = icmp slt i64 %11, 1
  %14 = icmp sgt i64 %11, %12
  %or.cond = select i1 %13, i1 %14, i1 false
  %15 = sub nsw i64 %7, %0
  %16 = select i1 %or.cond, i64 %3, i64 %15
  %17 = icmp slt i64 %7, %16
  br i1 %17, label %27, label %18, !prof !39

18:                                               ; preds = %10
  %19 = icmp slt i64 %16, %3
  br i1 %19, label %28, label %20, !prof !39

20:                                               ; preds = %18
  %21 = insertvalue { ptr, ptr, i64, i64 } undef, ptr %1, 0
  %22 = insertvalue { ptr, ptr, i64, i64 } %21, ptr %2, 1
  %23 = insertvalue { ptr, ptr, i64, i64 } %22, i64 %16, 2
  %24 = insertvalue { ptr, ptr, i64, i64 } %23, i64 %4, 3
  ret { ptr, ptr, i64, i64 } %24

25:                                               ; preds = %entry
  tail call void asm sideeffect "", "n"(i32 0) #10
  tail call void @llvm.trap()
  unreachable

26:                                               ; preds = %6
  tail call void asm sideeffect "", "n"(i32 2) #10
  tail call void @llvm.trap()
  unreachable

27:                                               ; preds = %10
  tail call void asm sideeffect "", "n"(i32 4) #10
  tail call void @llvm.trap()
  unreachable

28:                                               ; preds = %18
  tail call void asm sideeffect "", "n"(i32 5) #10
  tail call void @llvm.trap()
  unreachable
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc i1 @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V23__derived_struct_equalsySbAC_ACtFZ"(i64 %0, i64 %1, i64 %2, i64 %3) #0 {
entry:
  %4 = icmp eq i64 %0, %2
  %5 = icmp eq i64 %1, %3
  %spec.select = select i1 %4, i1 %5, i1 false
  ret i1 %spec.select
}

define swiftcc void @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V4hash4intoys6HasherVz_tF"(ptr captures(none) dereferenceable(72) %0, i64 %1, i64 %2) #3 {
entry:
  tail call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %1, ptr nonnull swiftself captures(none) dereferenceable(72) %0)
  tail call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %2, ptr nonnull swiftself captures(none) dereferenceable(72) %0)
  ret void
}

define swiftcc i64 @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2V9hashValueSivg"(i64 %0, i64 %1) #3 {
entry:
  %2 = alloca %Ts6HasherV, align 8
  call void @llvm.lifetime.start.p0(i64 72, ptr nonnull %2)
  call swiftcc void @"$ss6HasherV5_seedABSi_tcfC"(ptr noalias nonnull sret(%Ts6HasherV) captures(none) %2, i64 0)
  call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %0, ptr nonnull swiftself captures(none) dereferenceable(72) %2)
  call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %1, ptr nonnull swiftself captures(none) dereferenceable(72) %2)
  %3 = call swiftcc i64 @"$ss6HasherV9_finalizeSiyF"(ptr nonnull swiftself captures(none) dereferenceable(72) %2)
  call void @llvm.lifetime.end.p0(i64 72, ptr nonnull %2)
  ret i64 %3
}

define linkonce_odr hidden swiftcc i1 @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAASQ2eeoiySbx_xtFZTW"(ptr noalias captures(none) dereferenceable(16) %0, ptr noalias captures(none) dereferenceable(16) %1, ptr swiftself %2, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %3 = load i64, ptr %0, align 8
  %4 = load i64, ptr %1, align 8
  %5 = icmp eq i64 %3, %4
  br i1 %5, label %6, label %10

6:                                                ; preds = %entry
  %.c12 = getelementptr inbounds nuw i8, ptr %1, i64 8
  %7 = load i64, ptr %.c12, align 8
  %.c1 = getelementptr inbounds nuw i8, ptr %0, i64 8
  %8 = load i64, ptr %.c1, align 8
  %9 = icmp eq i64 %8, %7
  br label %10

10:                                               ; preds = %entry, %6
  %11 = phi i1 [ %9, %6 ], [ false, %entry ]
  ret i1 %11
}

define linkonce_odr hidden swiftcc i64 @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAASH9hashValueSivgTW"(ptr noalias swiftself captures(none) dereferenceable(16) %0, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %1 = alloca %Ts6HasherV, align 8
  %2 = load i64, ptr %0, align 8
  %.c1 = getelementptr inbounds nuw i8, ptr %0, i64 8
  %3 = load i64, ptr %.c1, align 8
  call void @llvm.lifetime.start.p0(i64 72, ptr nonnull %1)
  call swiftcc void @"$ss6HasherV5_seedABSi_tcfC"(ptr noalias nonnull sret(%Ts6HasherV) captures(none) %1, i64 0) #25
  call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %2, ptr nonnull swiftself captures(none) dereferenceable(72) %1) #25
  call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %3, ptr nonnull swiftself captures(none) dereferenceable(72) %1) #25
  %4 = call swiftcc i64 @"$ss6HasherV9_finalizeSiyF"(ptr nonnull swiftself captures(none) dereferenceable(72) %1) #25
  call void @llvm.lifetime.end.p0(i64 72, ptr nonnull %1)
  ret i64 %4
}

define linkonce_odr hidden swiftcc void @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAASH4hash4intoys6HasherVz_tFTW"(ptr captures(none) dereferenceable(72) %0, ptr noalias swiftself captures(none) dereferenceable(16) %1, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %2 = load i64, ptr %1, align 8
  %.c1 = getelementptr inbounds nuw i8, ptr %1, i64 8
  %3 = load i64, ptr %.c1, align 8
  tail call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %2, ptr nonnull swiftself captures(none) dereferenceable(72) %0) #25
  tail call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %3, ptr nonnull swiftself captures(none) dereferenceable(72) %0) #25
  ret void
}

define linkonce_odr hidden swiftcc i64 @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAASH13_rawHashValue4seedS2i_tFTW"(i64 %0, ptr noalias swiftself captures(none) dereferenceable(16) %1, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %2 = alloca %Ts6HasherV, align 8
  %3 = load i64, ptr %1, align 8
  %.c1 = getelementptr inbounds nuw i8, ptr %1, i64 8
  %4 = load i64, ptr %.c1, align 8
  call void @llvm.lifetime.start.p0(i64 72, ptr nonnull %2)
  call swiftcc void @"$ss6HasherV5_seedABSi_tcfC"(ptr noalias nonnull sret(%Ts6HasherV) captures(none) %2, i64 %0) #25
  call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %3, ptr nonnull swiftself captures(none) dereferenceable(72) %2) #25
  call swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64 %4, ptr nonnull swiftself captures(none) dereferenceable(72) %2) #25
  %5 = call swiftcc i64 @"$ss6HasherV9_finalizeSiyF"(ptr nonnull swiftself captures(none) dereferenceable(72) %2) #25
  call void @llvm.lifetime.end.p0(i64 72, ptr nonnull %2)
  ret i64 %5
}

define swiftcc i1 @"$s19SuperNeo_NuMetal_CT0aB5ErrorO21__derived_enum_equalsySbAC_ACtFZ"(i64 %0, i64 %1, i8 %2, i64 %3, i64 %4, i8 %5) #3 {
entry:
  %6 = tail call swiftcc i1 @"$s19SuperNeo_NuMetal_CT0aB5ErrorO21__derived_enum_equalsySbAC_ACtFZTf4nnd_n"(i64 %0, i64 %1, i8 %2, i64 %3, i64 %4, i8 %5) #25
  ret i1 %6
}

define linkonce_odr hidden swiftcc { i64, ptr } @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAsADP7_domainSSvgTW"(ptr noalias swiftself captures(none) dereferenceable(17) %0, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %1 = tail call swiftcc { i64, ptr } @"$ss5ErrorPsE7_domainSSvg"(ptr %Self, ptr %SelfWitnessTable, ptr noalias nonnull swiftself %0) #25
  ret { i64, ptr } %1
}

define linkonce_odr hidden swiftcc i64 @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAsADP5_codeSivgTW"(ptr noalias swiftself captures(none) dereferenceable(17) %0, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %1 = tail call swiftcc i64 @"$ss5ErrorPsE5_codeSivg"(ptr %Self, ptr %SelfWitnessTable, ptr noalias nonnull swiftself %0) #25
  ret i64 %1
}

define linkonce_odr hidden swiftcc i64 @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAsADP9_userInfoyXlSgvgTW"(ptr noalias swiftself captures(none) dereferenceable(17) %0, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %1 = tail call swiftcc i64 @"$ss5ErrorPsE9_userInfoyXlSgvg"(ptr %Self, ptr %SelfWitnessTable, ptr noalias nonnull swiftself %0) #25
  ret i64 %1
}

define linkonce_odr hidden swiftcc i64 @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAsADP19_getEmbeddedNSErroryXlSgyFTW"(ptr noalias swiftself captures(none) dereferenceable(17) %0, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %1 = tail call swiftcc i64 @"$ss5ErrorPsE19_getEmbeddedNSErroryXlSgyF"(ptr %Self, ptr %SelfWitnessTable, ptr noalias nonnull swiftself %0) #25
  ret i64 %1
}

define linkonce_odr hidden swiftcc i1 @"$s19SuperNeo_NuMetal_CT0aB5ErrorOSQAASQ2eeoiySbx_xtFZTW"(ptr noalias captures(none) dereferenceable(17) %0, ptr noalias captures(none) dereferenceable(17) %1, ptr swiftself %2, ptr %Self, ptr %SelfWitnessTable) #3 {
entry:
  %3 = load i64, ptr %0, align 8
  %4 = getelementptr inbounds nuw i8, ptr %0, i64 8
  %5 = load i64, ptr %4, align 8
  %6 = getelementptr inbounds nuw i8, ptr %0, i64 16
  %7 = load i8, ptr %6, align 8
  %8 = load i64, ptr %1, align 8
  %9 = getelementptr inbounds nuw i8, ptr %1, i64 8
  %10 = load i64, ptr %9, align 8
  %11 = getelementptr inbounds nuw i8, ptr %1, i64 16
  %12 = load i8, ptr %11, align 8
  %13 = tail call swiftcc i1 @"$s19SuperNeo_NuMetal_CT0aB5ErrorO21__derived_enum_equalsySbAC_ACtFZTf4nnd_n"(i64 %3, i64 %5, i8 %7, i64 %8, i64 %10, i8 %12) #25
  ret i1 %13
}

define linkonce_odr hidden swiftcc void @"$sSa6append10contentsOfyqd__n_t7ElementQyd__RszSTRd__lFs5UInt8V_SayAFGTg5"(ptr %0, ptr swiftself captures(none) dereferenceable(8) %1) local_unnamed_addr #3 {
entry:
  %2 = getelementptr inbounds nuw i8, ptr %0, i64 16
  %3 = load i64, ptr %2, align 8, !range !40
  %4 = load ptr, ptr %1, align 8
  %5 = getelementptr inbounds nuw i8, ptr %4, i64 16
  %6 = load i64, ptr %5, align 8, !range !40
  %7 = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %6, i64 %3)
  %8 = extractvalue { i64, i1 } %7, 0
  %9 = extractvalue { i64, i1 } %7, 1
  br i1 %9, label %39, label %10, !prof !39

10:                                               ; preds = %entry
  %11 = tail call zeroext i1 @swift_isUniquelyReferenced_nonNull_native(ptr nonnull %4) #29
  br i1 %11, label %12, label %16

12:                                               ; preds = %10
  %._storage6._capacityAndFlags = getelementptr inbounds nuw i8, ptr %4, i64 24
  %13 = load i64, ptr %._storage6._capacityAndFlags, align 8
  %14 = lshr i64 %13, 1
  %15 = icmp slt i64 %14, %8
  br i1 %15, label %16, label %18, !prof !39

16:                                               ; preds = %12, %10
  %. = tail call i64 @llvm.smax.i64(i64 %6, i64 %8)
  %17 = tail call swiftcc ptr @"$ss12_ArrayBufferV20_consumeAndCreateNew14bufferIsUnique15minimumCapacity13growForAppendAByxGSb_SiSbtFs5UInt8V_Tg5"(i1 %11, i64 %., i1 true, ptr nonnull %4)
  %._storage2._capacityAndFlags.phi.trans.insert = getelementptr inbounds nuw i8, ptr %17, i64 24
  %.pre = load i64, ptr %._storage2._capacityAndFlags.phi.trans.insert, align 8
  %.pre11 = lshr i64 %.pre, 1
  br label %18

18:                                               ; preds = %12, %16
  %.pre-phi = phi i64 [ %14, %12 ], [ %.pre11, %16 ]
  %19 = phi ptr [ %4, %12 ], [ %17, %16 ]
  %20 = getelementptr inbounds nuw i8, ptr %19, i64 16
  %21 = load i64, ptr %20, align 8, !range !40
  %22 = sub nsw i64 %.pre-phi, %21
  %23 = icmp sgt i64 %22, -1
  tail call void @llvm.assume(i1 %23)
  %24 = load i64, ptr %2, align 8, !range !40
  %25 = icmp eq i64 %24, 0
  br i1 %25, label %26, label %31

26:                                               ; preds = %18
  tail call void @swift_bridgeObjectRelease(ptr nonnull %0) #10
  %.not10 = icmp eq i64 %3, 0
  br i1 %.not10, label %.thread8, label %41, !prof !41

27:                                               ; preds = %31
  %28 = getelementptr inbounds nuw i8, ptr %19, i64 32
  %29 = getelementptr inbounds nuw %Ts5UInt8V, ptr %28, i64 %21
  %30 = getelementptr inbounds nuw i8, ptr %0, i64 32
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %29, ptr nonnull align 1 %30, i64 %3, i1 false)
  tail call void @swift_bridgeObjectRelease(ptr nonnull %0) #10
  %.not = icmp eq i64 %3, 0
  br i1 %.not, label %.thread8, label %33

31:                                               ; preds = %18
  %32 = icmp samesign ult i64 %22, %3
  br i1 %32, label %40, label %27, !prof !39

33:                                               ; preds = %27
  %34 = load i64, ptr %20, align 8, !range !40
  %35 = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %34, i64 %3)
  %36 = extractvalue { i64, i1 } %35, 1
  br i1 %36, label %42, label %37, !prof !39

37:                                               ; preds = %33
  %38 = extractvalue { i64, i1 } %35, 0
  store i64 %38, ptr %20, align 8
  br label %.thread8

.thread8:                                         ; preds = %26, %37, %27
  store ptr %19, ptr %1, align 8
  ret void

39:                                               ; preds = %entry
  tail call void asm sideeffect "", "n"(i32 0) #10
  tail call void @llvm.trap()
  unreachable

40:                                               ; preds = %31
  tail call void asm sideeffect "", "n"(i32 2) #10
  tail call void @llvm.trap()
  unreachable

41:                                               ; preds = %26
  tail call void asm sideeffect "", "n"(i32 3) #10
  tail call void @llvm.trap()
  unreachable

42:                                               ; preds = %33
  tail call void asm sideeffect "", "n"(i32 4) #10
  tail call void @llvm.trap()
  unreachable
}

; Function Attrs: noinline
define linkonce_odr hidden swiftcc ptr @"$ss12_ArrayBufferV20_consumeAndCreateNew14bufferIsUnique15minimumCapacity13growForAppendAByxGSb_SiSbtFs5UInt8V_Tg5"(i1 %0, i64 %1, i1 %2, ptr %3) local_unnamed_addr #7 {
entry:
  %4 = getelementptr inbounds nuw i8, ptr %3, i64 16
  br i1 %2, label %5, label %14

5:                                                ; preds = %entry
  %._storage._capacityAndFlags = getelementptr inbounds nuw i8, ptr %3, i64 24
  %6 = load i64, ptr %._storage._capacityAndFlags, align 8
  %7 = lshr i64 %6, 1
  %8 = icmp slt i64 %7, %1
  br i1 %8, label %9, label %14

9:                                                ; preds = %5
  %10 = add nuw i64 %7, 4611686018427387904
  %11 = icmp slt i64 %10, 0
  br i1 %11, label %34, label %12, !prof !39

12:                                               ; preds = %9
  %13 = and i64 %6, -2
  %. = tail call i64 @llvm.smax.i64(i64 %13, i64 %1)
  br label %14

14:                                               ; preds = %5, %12, %entry
  %15 = phi i64 [ %1, %entry ], [ %., %12 ], [ %7, %5 ]
  %16 = load i64, ptr %4, align 8, !range !40
  %.4 = tail call i64 @llvm.smax.i64(i64 %15, i64 %16)
  %17 = icmp eq i64 %.4, 0
  br i1 %17, label %24, label %18

18:                                               ; preds = %14
  %19 = tail call ptr @__swift_instantiateConcreteTypeFromMangledNameV2(ptr nonnull @"$ss23_ContiguousArrayStorageCys5UInt8VGMd", ptr nonnull @"$ss23_ContiguousArrayStorageCys5UInt8VGMR") #27
  %20 = add nuw i64 %.4, 32
  %21 = tail call noalias ptr @swift_allocObject(ptr %19, i64 %20, i64 7) #10
  %call.i = tail call i64 @malloc_size(ptr noundef %21) #28, !clang.arc.no_objc_arc_exceptions !38
  %gepdiff = shl i64 %call.i, 1
  %22 = add i64 %gepdiff, -64
  %23 = getelementptr inbounds nuw i8, ptr %21, i64 16
  store i64 %16, ptr %23, align 8
  %._storage3._capacityAndFlags = getelementptr inbounds nuw i8, ptr %21, i64 24
  store i64 %22, ptr %._storage3._capacityAndFlags, align 8
  br label %24

24:                                               ; preds = %14, %18
  %25 = phi ptr [ %21, %18 ], [ @_swiftEmptyArrayStorage, %14 ]
  %26 = getelementptr inbounds nuw i8, ptr %25, i64 32
  %27 = getelementptr inbounds nuw i8, ptr %3, i64 32
  br i1 %0, label %28, label %32

28:                                               ; preds = %24
  %29 = getelementptr inbounds nuw %Ts5UInt8V, ptr %27, i64 %16
  %30 = icmp ult ptr %26, %29
  %.not = icmp eq ptr %25, %3
  %or.cond9 = select i1 %.not, i1 %30, i1 false
  br i1 %or.cond9, label %31, label %.sink.split

.sink.split:                                      ; preds = %28
  tail call void @llvm.memmove.p0.p0.i64(ptr nonnull align 1 %26, ptr nonnull align 1 %27, i64 %16, i1 false)
  br label %31

31:                                               ; preds = %28, %.sink.split
  store i64 0, ptr %4, align 8
  br label %33

32:                                               ; preds = %24
  tail call void @llvm.memcpy.p0.p0.i64(ptr nonnull align 1 %26, ptr nonnull align 1 %27, i64 %16, i1 false)
  br label %33

33:                                               ; preds = %31, %32
  tail call void @swift_bridgeObjectRelease(ptr nonnull %3) #10
  ret ptr %25

34:                                               ; preds = %9
  tail call void asm sideeffect "", "n"(i32 0) #10
  tail call void @llvm.trap()
  unreachable
}

define linkonce_odr hidden swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV1poiyA2C_ACtFZTf4nnd_n"(i64 %0, i64 %1) local_unnamed_addr #3 {
entry:
  %2 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %0, i64 %1)
  %3 = extractvalue { i64, i1 } %2, 0
  %4 = extractvalue { i64, i1 } %2, 1
  %5 = select i1 %4, i64 4294967295, i64 0
  %6 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %3, i64 %5)
  %7 = extractvalue { i64, i1 } %6, 0
  %8 = extractvalue { i64, i1 } %6, 1
  %9 = select i1 %8, i64 4294967295, i64 0
  %10 = tail call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %7, i64 %9)
  %11 = extractvalue { i64, i1 } %10, 0
  %12 = extractvalue { i64, i1 } %10, 1
  %13 = select i1 %12, i64 4294967295, i64 0
  %14 = add i64 %13, %11
  %15 = icmp ult i64 %14, -4294967295
  %16 = tail call i64 @llvm.usub.sat.i64(i64 %14, i64 -4294967295)
  %17 = select i1 %15, i64 %14, i64 0
  %18 = or i64 %17, %16
  ret i64 %18
}

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.uadd.with.overflow.i64(i64, i64) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.ssub.with.overflow.i64(i64, i64) #1

; Function Attrs: nofree noinline nosync nounwind memory(none)
define linkonce_odr hidden ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOACs0F0AAWl"() local_unnamed_addr #8 {
entry:
  %0 = load ptr, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOACs0F0AAWL", align 8
  %1 = icmp eq ptr %0, null
  br i1 %1, label %cacheIsNull, label %cont

cacheIsNull:                                      ; preds = %entry
  %2 = tail call ptr @swift_getWitnessTable(ptr nonnull @"$s19SuperNeo_NuMetal_CT0aB5ErrorOs0F0AAMc", ptr nonnull getelementptr inbounds nuw (i8, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMf", i64 16), ptr undef) #27
  store atomic ptr %2, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOACs0F0AAWL" release, align 8
  br label %cont

cont:                                             ; preds = %cacheIsNull, %entry
  %3 = phi ptr [ %0, %entry ], [ %2, %cacheIsNull ]
  ret ptr %3
}

; Function Attrs: nofree nounwind memory(read)
declare ptr @swift_getWitnessTable(ptr, ptr, ptr) local_unnamed_addr #9

; Function Attrs: nounwind
declare swiftcc { ptr, ptr } @swift_allocError(ptr, ptr, ptr, i1) local_unnamed_addr #10

; Function Attrs: nounwind
declare swiftcc void @swift_willThrow(ptr swiftself, ptr swifterror) local_unnamed_addr #10

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.start.p0(i64 immarg, ptr captures(none)) #11

; Function Attrs: mustprogress nofree noinline nounwind willreturn memory(read)
define linkonce_odr hidden ptr @__swift_instantiateConcreteTypeFromMangledNameV2(ptr %0, ptr %1) local_unnamed_addr #12 {
entry:
  %2 = load atomic ptr, ptr %0 monotonic, align 8
  %3 = icmp eq ptr %2, null
  %4 = ptrtoint ptr %2 to i64
  %5 = and i64 %4, 1
  %6 = icmp ne i64 %5, 0
  %7 = or i1 %3, %6
  br i1 %7, label %10, label %8

8:                                                ; preds = %10, %entry
  %9 = phi ptr [ %2, %entry ], [ %17, %10 ]
  ret ptr %9

10:                                               ; preds = %entry
  %11 = load i64, ptr %1, align 8
  %12 = ashr i64 %11, 32
  %sext = shl i64 %11, 32
  %13 = ashr exact i64 %sext, 32
  %14 = ptrtoint ptr %1 to i64
  %15 = add i64 %13, %14
  %16 = inttoptr i64 %15 to ptr
  %17 = tail call swiftcc ptr @swift_getTypeByMangledNameInContext2(ptr %16, i64 %12, ptr null, ptr null) #30
  store atomic ptr %17, ptr %0 monotonic, align 8
  br label %8
}

; Function Attrs: nounwind memory(argmem: readwrite)
declare swiftcc ptr @swift_getTypeByMangledNameInContext2(ptr, i64, ptr, ptr) local_unnamed_addr #13

; Function Attrs: nounwind
declare ptr @swift_allocObject(ptr, i64, i64) local_unnamed_addr #10

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite)
declare void @llvm.lifetime.end.p0(i64 immarg, ptr captures(none)) #11

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memmove.p0.p0.i64(ptr writeonly captures(none), ptr readonly captures(none), i64, i1 immarg) #14

define linkonce_odr hidden swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV17littleEndianBytesACs10ArraySliceVys5UInt8VG_tKcfCTf4gXd_n"(ptr %0, i64 %1, i64 %2, ptr swiftself %3, ptr noalias swifterror captures(none) dereferenceable(8) %4) local_unnamed_addr #3 {
entry:
  %5 = lshr i64 %2, 1
  %6 = tail call { i64, i1 } @llvm.ssub.with.overflow.i64(i64 %5, i64 %1)
  %7 = extractvalue { i64, i1 } %6, 1
  br i1 %7, label %44, label %8, !prof !39

8:                                                ; preds = %entry
  %9 = extractvalue { i64, i1 } %6, 0
  %10 = icmp eq i64 %9, 8
  br i1 %10, label %11, label %36

11:                                               ; preds = %8
  %12 = icmp eq i64 %1, %5
  br i1 %12, label %common.ret, label %13

13:                                               ; preds = %11
  %.not = icmp slt i64 %1, %5
  br i1 %.not, label %.preheader.preheader, label %45, !prof !42

.preheader.preheader:                             ; preds = %13, %.preheader
  %14 = phi i64 [ %27, %.preheader ], [ 0, %13 ]
  %.in = phi i64 [ %18, %.preheader ], [ %1, %13 ]
  %15 = phi i64 [ %25, %.preheader ], [ 0, %13 ]
  %16 = phi i64 [ %26, %.preheader ], [ 1, %13 ]
  %.in18 = getelementptr inbounds %Ts5UInt8V, ptr %0, i64 %.in
  %17 = load i8, ptr %.in18, align 1
  %18 = add i64 %.in, 1
  %19 = icmp samesign ugt i64 %14, 64
  br i1 %19, label %20, label %22

20:                                               ; preds = %.preheader.preheader
  %21 = icmp eq i64 %18, %5
  br i1 %21, label %28, label %.preheader

22:                                               ; preds = %.preheader.preheader
  %.not6 = icmp eq i64 %14, 64
  br i1 %.not6, label %23, label %31, !prof !39

23:                                               ; preds = %22
  %24 = icmp eq i64 %18, %5
  br i1 %24, label %28, label %.preheader

.preheader:                                       ; preds = %31, %23, %20
  %25 = phi i64 [ %15, %20 ], [ %15, %23 ], [ %34, %31 ]
  %26 = add nuw nsw i64 %16, 1
  %27 = shl i64 %16, 3
  %exitcond = icmp eq i64 %26, 1152921504606846977
  br i1 %exitcond, label %46, label %.preheader.preheader, !prof !43

28:                                               ; preds = %31, %23, %20
  %29 = phi i64 [ %15, %20 ], [ %15, %23 ], [ %34, %31 ]
  %30 = icmp ult i64 %29, -4294967295
  br i1 %30, label %common.ret, label %36

31:                                               ; preds = %22
  %32 = zext i8 %17 to i64
  %33 = shl i64 %32, %14
  %34 = or i64 %33, %15
  %35 = icmp eq i64 %18, %5
  br i1 %35, label %28, label %.preheader

common.ret:                                       ; preds = %11, %28, %36
  %common.ret.op = phi i64 [ undef, %36 ], [ 0, %11 ], [ %29, %28 ]
  ret i64 %common.ret.op

36:                                               ; preds = %8, %28
  %.sink16 = phi i64 [ sub (i64 ptrtoint (ptr @".str.32.non-canonical Goldilocks element" to i64), i64 32), %28 ], [ sub (i64 ptrtoint (ptr @".str.34.Goldilocks element must be 8 bytes" to i64), i64 32), %8 ]
  %.sink12 = phi i64 [ -3458764513820540896, %28 ], [ -3458764513820540894, %8 ]
  %37 = or i64 %.sink16, -9223372036854775808
  %38 = tail call ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOACs0F0AAWl"() #26
  %39 = tail call swiftcc { ptr, ptr } @swift_allocError(ptr nonnull getelementptr inbounds nuw (i8, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMf", i64 16), ptr %38, ptr null, i1 false) #10
  %40 = extractvalue { ptr, ptr } %39, 1
  store i64 %.sink12, ptr %40, align 8
  %41 = getelementptr inbounds nuw i8, ptr %40, i64 8
  store i64 %37, ptr %41, align 8
  %42 = getelementptr inbounds nuw i8, ptr %40, i64 16
  store i8 0, ptr %42, align 8
  %43 = extractvalue { ptr, ptr } %39, 0
  store ptr %43, ptr %4, align 8
  tail call swiftcc void @swift_willThrow(ptr swiftself undef, ptr noalias nonnull readonly swifterror captures(none) dereferenceable(8) %4) #10
  store ptr %43, ptr %4, align 8
  br label %common.ret

44:                                               ; preds = %entry
  tail call void asm sideeffect "", "n"(i32 0) #10
  tail call void @llvm.trap()
  unreachable

45:                                               ; preds = %13
  tail call void asm sideeffect "", "n"(i32 1) #10
  tail call void @llvm.trap()
  unreachable

46:                                               ; preds = %.preheader
  tail call void asm sideeffect "", "n"(i32 5) #10
  tail call void @llvm.trap()
  unreachable
}

; Function Attrs: nounwind
declare void @swift_unknownObjectRelease(ptr) local_unnamed_addr #10

declare swiftcc void @"$ss6HasherV8_combineyys6UInt64VF"(i64, ptr swiftself captures(none) dereferenceable(72)) local_unnamed_addr #3

declare swiftcc void @"$ss6HasherV5_seedABSi_tcfC"(ptr noalias sret(%Ts6HasherV) captures(none), i64) local_unnamed_addr #3

; Function Attrs: mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias writeonly captures(none), ptr noalias readonly captures(none), i64, i1 immarg) #14

declare swiftcc i64 @"$ss6HasherV9_finalizeSiyF"(ptr swiftself captures(none) dereferenceable(72)) local_unnamed_addr #3

define linkonce_odr hidden swiftcc i1 @"$s19SuperNeo_NuMetal_CT0aB5ErrorO21__derived_enum_equalsySbAC_ACtFZTf4nnd_n"(i64 %0, i64 %1, i8 %2, i64 %3, i64 %4, i8 %5) local_unnamed_addr #3 {
entry:
  switch i8 %2, label %9 [
    i8 0, label %10
    i8 1, label %12
    i8 2, label %14
    i8 3, label %16
    i8 4, label %18
    i8 5, label %6
  ]

6:                                                ; preds = %entry
  %7 = or i64 %1, %0
  %8 = icmp eq i64 %7, 0
  %.not14 = icmp eq i8 %5, 5
  br i1 %8, label %20, label %41

9:                                                ; preds = %entry
  unreachable

10:                                               ; preds = %entry
  %11 = inttoptr i64 %1 to ptr
  %.not19 = icmp eq i8 %5, 0
  br i1 %.not19, label %23, label %58

12:                                               ; preds = %entry
  %13 = inttoptr i64 %1 to ptr
  %.not18 = icmp eq i8 %5, 1
  br i1 %.not18, label %29, label %58

14:                                               ; preds = %entry
  %15 = inttoptr i64 %1 to ptr
  %.not17 = icmp eq i8 %5, 2
  br i1 %.not17, label %35, label %58

16:                                               ; preds = %entry
  %17 = inttoptr i64 %1 to ptr
  %.not16 = icmp eq i8 %5, 3
  br i1 %.not16, label %46, label %58

18:                                               ; preds = %entry
  %19 = inttoptr i64 %1 to ptr
  %.not15 = icmp eq i8 %5, 4
  br i1 %.not15, label %52, label %58

20:                                               ; preds = %6
  %21 = or i64 %4, %3
  %22 = icmp eq i64 %21, 0
  %or.cond = select i1 %.not14, i1 %22, i1 false
  br i1 %or.cond, label %59, label %58

23:                                               ; preds = %10
  %24 = icmp eq i64 %0, %3
  %25 = icmp eq i64 %1, %4
  %or.cond21 = select i1 %24, i1 %25, i1 false
  br i1 %or.cond21, label %59, label %26

26:                                               ; preds = %23
  %27 = inttoptr i64 %4 to ptr
  %28 = tail call swiftcc i1 @"$ss27_stringCompareWithSmolCheck__9expectingSbs11_StringGutsV_ADs01_G16ComparisonResultOtF"(i64 %0, ptr %11, i64 %3, ptr %27, i8 0)
  br label %59

29:                                               ; preds = %12
  %30 = icmp eq i64 %0, %3
  %31 = icmp eq i64 %1, %4
  %or.cond22 = select i1 %30, i1 %31, i1 false
  br i1 %or.cond22, label %59, label %32

32:                                               ; preds = %29
  %33 = inttoptr i64 %4 to ptr
  %34 = tail call swiftcc i1 @"$ss27_stringCompareWithSmolCheck__9expectingSbs11_StringGutsV_ADs01_G16ComparisonResultOtF"(i64 %0, ptr %13, i64 %3, ptr %33, i8 0)
  br label %59

35:                                               ; preds = %14
  %36 = icmp eq i64 %0, %3
  %37 = icmp eq i64 %1, %4
  %or.cond23 = select i1 %36, i1 %37, i1 false
  br i1 %or.cond23, label %59, label %38

38:                                               ; preds = %35
  %39 = inttoptr i64 %4 to ptr
  %40 = tail call swiftcc i1 @"$ss27_stringCompareWithSmolCheck__9expectingSbs11_StringGutsV_ADs01_G16ComparisonResultOtF"(i64 %0, ptr %15, i64 %3, ptr %39, i8 0)
  br label %59

41:                                               ; preds = %6
  br i1 %.not14, label %42, label %58

42:                                               ; preds = %41
  %43 = icmp eq i64 %3, 1
  %44 = icmp eq i64 %4, 0
  %45 = and i1 %43, %44
  br i1 %45, label %59, label %58

46:                                               ; preds = %16
  %47 = icmp eq i64 %0, %3
  %48 = icmp eq i64 %1, %4
  %or.cond24 = select i1 %47, i1 %48, i1 false
  br i1 %or.cond24, label %59, label %49

49:                                               ; preds = %46
  %50 = inttoptr i64 %4 to ptr
  %51 = tail call swiftcc i1 @"$ss27_stringCompareWithSmolCheck__9expectingSbs11_StringGutsV_ADs01_G16ComparisonResultOtF"(i64 %0, ptr %17, i64 %3, ptr %50, i8 0)
  br label %59

52:                                               ; preds = %18
  %53 = icmp eq i64 %0, %3
  %54 = icmp eq i64 %1, %4
  %or.cond25 = select i1 %53, i1 %54, i1 false
  br i1 %or.cond25, label %59, label %55

55:                                               ; preds = %52
  %56 = inttoptr i64 %4 to ptr
  %57 = tail call swiftcc i1 @"$ss27_stringCompareWithSmolCheck__9expectingSbs11_StringGutsV_ADs01_G16ComparisonResultOtF"(i64 %0, ptr %19, i64 %3, ptr %56, i8 0)
  br label %59

58:                                               ; preds = %18, %16, %41, %42, %14, %12, %10, %20
  br label %59

59:                                               ; preds = %52, %46, %35, %29, %23, %20, %55, %49, %38, %32, %26, %42, %58
  %60 = phi i1 [ false, %58 ], [ true, %42 ], [ %28, %26 ], [ %34, %32 ], [ %40, %38 ], [ %51, %49 ], [ %57, %55 ], [ true, %20 ], [ true, %23 ], [ true, %29 ], [ true, %35 ], [ true, %46 ], [ true, %52 ]
  ret i1 %60
}

; Function Attrs: nofree nosync nounwind memory(none)
define internal swiftcc ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSHAASQWb"(ptr readnone captures(none) %GoldilocksField, ptr readnone captures(none) %GoldilocksField1, ptr readnone captures(none) %GoldilocksField.Hashable) #15 {
entry:
  %0 = tail call ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVACSQAAWl"() #26
  ret ptr %0
}

; Function Attrs: nofree noinline nosync nounwind memory(none)
define linkonce_odr hidden ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVACSQAAWl"() local_unnamed_addr #8 {
entry:
  %0 = load ptr, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVACSQAAWL", align 8
  %1 = icmp eq ptr %0, null
  br i1 %1, label %cacheIsNull, label %cont

cacheIsNull:                                      ; preds = %entry
  %2 = tail call ptr @swift_getWitnessTable(ptr nonnull @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVSQAAMc", ptr nonnull getelementptr inbounds nuw (i8, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMf", i64 16), ptr undef) #27
  store atomic ptr %2, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVACSQAAWL" release, align 8
  br label %cont

cont:                                             ; preds = %cacheIsNull, %entry
  %3 = phi ptr [ %0, %entry ], [ %2, %cacheIsNull ]
  ret ptr %3
}

; Function Attrs: nofree nosync nounwind memory(none)
define internal swiftcc ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSHAASQWb"(ptr readnone captures(none) %GoldilocksExt2, ptr readnone captures(none) %GoldilocksExt21, ptr readnone captures(none) %GoldilocksExt2.Hashable) #15 {
entry:
  %0 = tail call ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VACSQAAWl"() #26
  ret ptr %0
}

; Function Attrs: nofree noinline nosync nounwind memory(none)
define linkonce_odr hidden ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VACSQAAWl"() local_unnamed_addr #8 {
entry:
  %0 = load ptr, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VACSQAAWL", align 8
  %1 = icmp eq ptr %0, null
  br i1 %1, label %cacheIsNull, label %cont

cacheIsNull:                                      ; preds = %entry
  %2 = tail call ptr @swift_getWitnessTable(ptr nonnull @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VSQAAMc", ptr nonnull getelementptr inbounds nuw (i8, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMf", i64 16), ptr undef) #27
  store atomic ptr %2, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VACSQAAWL" release, align 8
  br label %cont

cont:                                             ; preds = %cacheIsNull, %entry
  %3 = phi ptr [ %0, %entry ], [ %2, %cacheIsNull ]
  ret ptr %3
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none)
define swiftcc %swift.metadata_response @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMa"(i64 %0) #16 {
entry:
  ret %swift.metadata_response { ptr getelementptr inbounds (<{ ptr, ptr, i64, ptr, i32, [4 x i8] }>, ptr @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVMf", i32 0, i32 2), i64 0 }
}

; Function Attrs: nounwind
define linkonce_odr hidden ptr @__swift_memcpy16_8(ptr %0, ptr %1, ptr %2) #5 {
entry:
  tail call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(16) %0, ptr noundef nonnull align 8 dereferenceable(16) %1, i64 16, i1 false)
  ret ptr %0
}

; Function Attrs: nounwind
define linkonce_odr hidden void @__swift_noop_void_return(ptr %0, ptr %1) #5 {
entry:
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read)
define internal i32 @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2Vwet"(ptr noalias readonly captures(none) %value, i32 %numEmptyCases, ptr readnone captures(none) %GoldilocksExt2) #17 {
entry:
  %0 = icmp eq i32 %numEmptyCases, 0
  br i1 %0, label %9, label %1

1:                                                ; preds = %entry
  %2 = getelementptr inbounds nuw i8, ptr %value, i64 16
  %3 = load i8, ptr %2, align 1
  %4 = icmp eq i8 %3, 0
  br i1 %4, label %9, label %5

5:                                                ; preds = %1
  %6 = load i128, ptr %value, align 1
  %7 = trunc i128 %6 to i32
  %8 = add i32 %7, 1
  br label %9

9:                                                ; preds = %entry, %1, %5
  %10 = phi i32 [ %8, %5 ], [ 0, %1 ], [ 0, %entry ]
  ret i32 %10
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write)
define internal void @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2Vwst"(ptr noalias writeonly captures(none) %value, i32 %whichCase, i32 %numEmptyCases, ptr readnone captures(none) %GoldilocksExt2) #18 {
entry:
  %0 = getelementptr inbounds nuw i8, ptr %value, i64 16
  %.not = icmp eq i32 %numEmptyCases, 0
  %1 = icmp eq i32 %whichCase, 0
  br i1 %1, label %2, label %3

2:                                                ; preds = %entry
  br i1 %.not, label %6, label %.sink.split

3:                                                ; preds = %entry
  %4 = add i32 %whichCase, -1
  %5 = zext i32 %4 to i128
  store i128 %5, ptr %value, align 8
  br i1 %.not, label %6, label %.sink.split

.sink.split:                                      ; preds = %3, %2
  %.sink = phi i8 [ 0, %2 ], [ 1, %3 ]
  store i8 %.sink, ptr %0, align 8
  br label %6

6:                                                ; preds = %.sink.split, %3, %2
  ret void
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none)
define swiftcc %swift.metadata_response @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMa"(i64 %0) #16 {
entry:
  ret %swift.metadata_response { ptr getelementptr inbounds (<{ ptr, ptr, i64, ptr, i32, i32 }>, ptr @"$s19SuperNeo_NuMetal_CT14GoldilocksExt2VMf", i32 0, i32 2), i64 0 }
}

; Function Attrs: nounwind
define internal ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwCP"(ptr noalias returned writeonly captures(ret: address, provenance) initializes((0, 17)) %dest, ptr noalias readonly captures(none) %src, ptr readnone captures(none) %SuperNeoError) #5 {
  %1 = tail call ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwCPTm"(ptr noalias returned writeonly captures(ret: address, provenance) initializes((0, 17)) %dest, ptr noalias readonly captures(none) %src, ptr readnone captures(none) %SuperNeoError) #5
  ret ptr %1
}

; Function Attrs: noinline nounwind
define linkonce_odr hidden void @"$s19SuperNeo_NuMetal_CT0aB5ErrorOWOy"(i64 %0, i64 %1, i8 %2) local_unnamed_addr #19 {
entry:
  %switch = icmp ult i8 %2, 5
  br i1 %switch, label %.sink.split, label %5

.sink.split:                                      ; preds = %entry
  %3 = inttoptr i64 %1 to ptr
  %4 = tail call ptr @swift_bridgeObjectRetain(ptr returned %3) #10
  br label %5

5:                                                ; preds = %entry, %.sink.split
  ret void
}

; Function Attrs: nounwind
declare ptr @swift_bridgeObjectRetain(ptr returned) local_unnamed_addr #10

; Function Attrs: nounwind
define internal void @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwxx"(ptr noalias readonly captures(none) %object, ptr readnone captures(none) %SuperNeoError) #5 {
entry:
  %0 = load i64, ptr %object, align 8
  %1 = getelementptr inbounds nuw i8, ptr %object, i64 8
  %2 = load i64, ptr %1, align 8
  %3 = getelementptr inbounds nuw i8, ptr %object, i64 16
  %4 = load i8, ptr %3, align 8
  tail call void @"$s19SuperNeo_NuMetal_CT0aB5ErrorOWOe"(i64 %0, i64 %2, i8 %4)
  ret void
}

; Function Attrs: noinline nounwind
define linkonce_odr hidden void @"$s19SuperNeo_NuMetal_CT0aB5ErrorOWOe"(i64 %0, i64 %1, i8 %2) local_unnamed_addr #19 {
entry:
  %switch = icmp ult i8 %2, 5
  br i1 %switch, label %.sink.split, label %4

.sink.split:                                      ; preds = %entry
  %3 = inttoptr i64 %1 to ptr
  tail call void @swift_bridgeObjectRelease(ptr %3) #10
  br label %4

4:                                                ; preds = %entry, %.sink.split
  ret void
}

; Function Attrs: nounwind
declare void @swift_bridgeObjectRelease(ptr) local_unnamed_addr #10

; Function Attrs: nounwind
define internal ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwCPTm"(ptr noalias returned writeonly captures(ret: address, provenance) initializes((0, 17)) %0, ptr noalias readonly captures(none) %1, ptr readnone captures(none) %2) #5 {
entry:
  %3 = load i64, ptr %1, align 8
  %4 = getelementptr inbounds nuw i8, ptr %1, i64 8
  %5 = load i64, ptr %4, align 8
  %6 = getelementptr inbounds nuw i8, ptr %1, i64 16
  %7 = load i8, ptr %6, align 8
  tail call void @"$s19SuperNeo_NuMetal_CT0aB5ErrorOWOy"(i64 %3, i64 %5, i8 %7)
  store i64 %3, ptr %0, align 8
  %8 = getelementptr inbounds nuw i8, ptr %0, i64 8
  store i64 %5, ptr %8, align 8
  %9 = getelementptr inbounds nuw i8, ptr %0, i64 16
  store i8 %7, ptr %9, align 8
  ret ptr %0
}

; Function Attrs: nounwind
define internal ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwca"(ptr returned captures(ret: address, provenance) %dest, ptr readonly captures(none) %src, ptr readnone captures(none) %SuperNeoError) #5 {
entry:
  %0 = load i64, ptr %src, align 8
  %1 = getelementptr inbounds nuw i8, ptr %src, i64 8
  %2 = load i64, ptr %1, align 8
  %3 = getelementptr inbounds nuw i8, ptr %src, i64 16
  %4 = load i8, ptr %3, align 8
  tail call void @"$s19SuperNeo_NuMetal_CT0aB5ErrorOWOy"(i64 %0, i64 %2, i8 %4)
  %5 = load i64, ptr %dest, align 8
  %6 = getelementptr inbounds nuw i8, ptr %dest, i64 8
  %7 = load i64, ptr %6, align 8
  %8 = getelementptr inbounds nuw i8, ptr %dest, i64 16
  %9 = load i8, ptr %8, align 8
  store i64 %0, ptr %dest, align 8
  store i64 %2, ptr %6, align 8
  store i8 %4, ptr %8, align 8
  tail call void @"$s19SuperNeo_NuMetal_CT0aB5ErrorOWOe"(i64 %5, i64 %7, i8 %9)
  ret ptr %dest
}

; Function Attrs: nounwind
define linkonce_odr hidden ptr @__swift_memcpy17_8(ptr %0, ptr %1, ptr %2) #5 {
entry:
  tail call void @llvm.memcpy.p0.p0.i64(ptr noundef nonnull align 8 dereferenceable(17) %0, ptr noundef nonnull align 8 dereferenceable(17) %1, i64 17, i1 false)
  ret ptr %0
}

; Function Attrs: nounwind
define internal noundef ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwta"(ptr noalias returned captures(ret: address, provenance) %dest, ptr noalias readonly captures(none) %src, ptr readnone captures(none) %SuperNeoError) #5 {
entry:
  %0 = getelementptr inbounds nuw i8, ptr %src, i64 16
  %1 = load i8, ptr %0, align 8
  %2 = load i64, ptr %dest, align 8
  %3 = getelementptr inbounds nuw i8, ptr %dest, i64 8
  %4 = load i64, ptr %3, align 8
  %5 = getelementptr inbounds nuw i8, ptr %dest, i64 16
  %6 = load i8, ptr %5, align 8
  %7 = load <2 x i64>, ptr %src, align 8
  store <2 x i64> %7, ptr %dest, align 8
  store i8 %1, ptr %5, align 8
  tail call void @"$s19SuperNeo_NuMetal_CT0aB5ErrorOWOe"(i64 %2, i64 %4, i8 %6)
  ret ptr %dest
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read)
define internal i32 @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwet"(ptr noalias readonly captures(none) %value, i32 %numEmptyCases, ptr readnone captures(none) %SuperNeoError) #17 {
entry:
  %0 = icmp eq i32 %numEmptyCases, 0
  br i1 %0, label %18, label %1

1:                                                ; preds = %entry
  %2 = icmp ugt i32 %numEmptyCases, 250
  br i1 %2, label %3, label %11

3:                                                ; preds = %1
  %4 = getelementptr inbounds nuw i8, ptr %value, i64 17
  %5 = load i8, ptr %4, align 1
  %6 = icmp eq i8 %5, 0
  br i1 %6, label %11, label %7

7:                                                ; preds = %3
  %8 = load i136, ptr %value, align 1
  %9 = trunc i136 %8 to i32
  %10 = add i32 %9, 250
  br label %18

11:                                               ; preds = %3, %1
  %12 = getelementptr inbounds nuw i8, ptr %value, i64 16
  %13 = load i8, ptr %12, align 8
  %14 = xor i8 %13, -1
  %15 = zext i8 %14 to i32
  %16 = icmp ugt i8 %13, 5
  %17 = select i1 %16, i32 %15, i32 -1
  br label %18

18:                                               ; preds = %entry, %11, %7
  %19 = phi i32 [ %17, %11 ], [ %10, %7 ], [ -1, %entry ]
  %20 = add i32 %19, 1
  ret i32 %20
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write)
define internal void @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwst"(ptr noalias writeonly captures(none) %value, i32 %whichCase, i32 %numEmptyCases, ptr readnone captures(none) %SuperNeoError) #18 {
entry:
  %0 = getelementptr inbounds nuw i8, ptr %value, i64 17
  %1 = icmp ugt i32 %numEmptyCases, 250
  %2 = icmp ult i32 %whichCase, 251
  br i1 %2, label %3, label %11

3:                                                ; preds = %entry
  br i1 %1, label %4, label %5

4:                                                ; preds = %3
  store i8 0, ptr %0, align 1
  br label %5

5:                                                ; preds = %3, %4
  %6 = icmp eq i32 %whichCase, 0
  br i1 %6, label %15, label %7

7:                                                ; preds = %5
  %8 = getelementptr inbounds nuw i8, ptr %value, i64 16
  %9 = trunc nuw i32 %whichCase to i8
  %10 = sub i8 0, %9
  store i8 %10, ptr %8, align 8
  br label %15

11:                                               ; preds = %entry
  %12 = add i32 %whichCase, -251
  %13 = zext i32 %12 to i136
  store i136 %13, ptr %value, align 8
  br i1 %1, label %14, label %15

14:                                               ; preds = %11
  store i8 1, ptr %0, align 1
  br label %15

15:                                               ; preds = %11, %14, %7, %5
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read)
define internal i32 @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwug"(ptr noalias readonly captures(none) %value, ptr readnone captures(none) %SuperNeoError) #17 {
entry:
  %0 = load i64, ptr %value, align 8
  %1 = getelementptr inbounds nuw i8, ptr %value, i64 16
  %2 = load i8, ptr %1, align 8
  %3 = zext i8 %2 to i32
  %4 = trunc i64 %0 to i32
  %5 = add i32 %4, 5
  %6 = icmp ugt i8 %2, 4
  %7 = select i1 %6, i32 %5, i32 %3
  ret i32 %7
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define internal void @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwup"(ptr noalias readnone captures(none) %value, ptr readnone captures(none) %SuperNeoError) #0 {
entry:
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write)
define internal void @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwui"(ptr noalias writeonly captures(none) initializes((16, 17)) %value, i32 %tag, ptr readnone captures(none) %SuperNeoError) #18 {
entry:
  %0 = icmp ugt i32 %tag, 4
  br i1 %0, label %1, label %5

1:                                                ; preds = %entry
  %2 = add i32 %tag, -5
  %3 = zext i32 %2 to i64
  store i64 %3, ptr %value, align 8
  %4 = getelementptr inbounds nuw i8, ptr %value, i64 8
  store i64 0, ptr %4, align 8
  br label %7

5:                                                ; preds = %entry
  %6 = trunc nuw nsw i32 %tag to i8
  br label %7

7:                                                ; preds = %5, %1
  %.sink = phi i8 [ 5, %1 ], [ %6, %5 ]
  %8 = getelementptr inbounds nuw i8, ptr %value, i64 16
  store i8 %.sink, ptr %8, align 8
  ret void
}

; Function Attrs: mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none)
define swiftcc %swift.metadata_response @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMa"(i64 %0) #16 {
entry:
  ret %swift.metadata_response { ptr getelementptr inbounds (<{ ptr, ptr, i64, ptr }>, ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOMf", i32 0, i32 2), i64 0 }
}

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftFoundation"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swift_Builtin_float"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftObjectiveC"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftCoreFoundation"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftDispatch"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftXPC"()

declare extern_weak void @"_swift_FORCE_LOAD_$_swiftIOKit"()

declare swiftcc i64 @"$ss5ErrorPsE19_getEmbeddedNSErroryXlSgyF"(ptr, ptr, ptr noalias swiftself) local_unnamed_addr #3

declare swiftcc i64 @"$ss5ErrorPsE9_userInfoyXlSgvg"(ptr, ptr, ptr noalias swiftself) local_unnamed_addr #3

declare swiftcc i64 @"$ss5ErrorPsE5_codeSivg"(ptr, ptr, ptr noalias swiftself) local_unnamed_addr #3

declare swiftcc { i64, ptr } @"$ss5ErrorPsE7_domainSSvg"(ptr, ptr, ptr noalias swiftself) local_unnamed_addr #3

declare swiftcc i1 @"$ss27_stringCompareWithSmolCheck__9expectingSbs11_StringGutsV_ADs01_G16ComparisonResultOtF"(i64, ptr, i64, ptr, i8) local_unnamed_addr #3

; Function Attrs: mustprogress nounwind willreturn
declare zeroext i1 @swift_isUniquelyReferenced_nonNull_native(ptr) local_unnamed_addr #20

; Function Attrs: mustprogress nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write)
declare void @llvm.assume(i1 noundef) #21

; Function Attrs: optsize
declare i64 @malloc_size(ptr noundef) local_unnamed_addr #22

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.usub.sat.i64(i64, i64) #23

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #23

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr writeonly captures(none), i8, i64, i1 immarg) #24

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldVyACs6UInt64VcfC"(i64 %0) #0 {
  %2 = tail call swiftcc i64 @"$s19SuperNeo_NuMetal_CT15GoldilocksFieldV14integerLiteralACs6UInt64V_tcfC"(i64 %0) #0
  ret i64 %2
}

; Function Attrs: nounwind
define internal ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwcp"(ptr noalias returned writeonly captures(ret: address, provenance) initializes((0, 17)) %0, ptr noalias readonly captures(none) %1, ptr readnone captures(none) %2) #5 {
  %4 = tail call ptr @"$s19SuperNeo_NuMetal_CT0aB5ErrorOwCP"(ptr noalias returned writeonly captures(ret: address, provenance) initializes((0, 17)) %0, ptr noalias readonly captures(none) %1, ptr readnone captures(none) %2) #5
  ret ptr %4
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #1 = { mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #3 = { "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #4 = { nofree norecurse nosync nounwind memory(none) "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #5 = { nounwind "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #6 = { sspreq "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #7 = { noinline "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #8 = { nofree noinline nosync nounwind memory(none) "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #9 = { nofree nounwind memory(read) }
attributes #10 = { nounwind }
attributes #11 = { mustprogress nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
attributes #12 = { mustprogress nofree noinline nounwind willreturn memory(read) "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #13 = { nounwind memory(argmem: readwrite) }
attributes #14 = { mustprogress nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #15 = { nofree nosync nounwind memory(none) "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #16 = { mustprogress nofree noinline norecurse nosync nounwind willreturn memory(none) "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #17 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #18 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write) "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #19 = { noinline nounwind "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #20 = { mustprogress nounwind willreturn }
attributes #21 = { mustprogress nocallback nofree nosync nounwind willreturn memory(inaccessiblemem: write) }
attributes #22 = { optsize "frame-pointer"="non-leaf" "no-trapping-math"="true" "probe-stack"="__chkstk_darwin" "stack-protector-buffer-size"="8" "target-cpu"="apple-m1" "target-features"="+aes,+altnzcv,+bti,+ccdp,+ccidx,+ccpp,+complxnum,+crc,+dit,+dotprod,+flagm,+fp-armv8,+fp16fml,+fptoint,+fullfp16,+jsconv,+lse,+neon,+pauth,+perfmon,+predres,+ras,+rcpc,+rdm,+sb,+sha2,+sha3,+specrestrict,+ssbs,+v8.1a,+v8.2a,+v8.3a,+v8.4a,+v8.5a,+v8a" }
attributes #23 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #24 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #25 = { noinline }
attributes #26 = { nounwind memory(none) }
attributes #27 = { nounwind memory(read) }
attributes #28 = { optsize }
attributes #29 = { nounwind willreturn }
attributes #30 = { nounwind memory(argmem: read) }

!llvm.module.flags = !{!0, !1, !2, !3, !4, !5, !6, !7, !8, !9, !10, !11}
!swift.module.flags = !{!12}
!llvm.linker.options = !{!13, !14, !15, !16, !17, !18, !19, !20, !21, !22, !23, !24, !25, !26, !27, !28, !29, !30, !31, !32, !33, !34, !35, !36, !37}

!0 = !{i32 2, !"SDK Version", [2 x i32] [i32 26, i32 4]}
!1 = !{i32 1, !"Objective-C Version", i32 2}
!2 = !{i32 1, !"Objective-C Image Info Version", i32 0}
!3 = !{i32 1, !"Objective-C Image Info Section", !"__DATA,__objc_imageinfo,regular,no_dead_strip"}
!4 = !{i32 4, !"Objective-C Garbage Collection", i32 100861696}
!5 = !{i32 1, !"Objective-C Class Properties", i32 64}
!6 = !{i32 1, !"Objective-C Enforce ClassRO Pointer Signing", i8 0}
!7 = !{i32 1, !"wchar_size", i32 4}
!8 = !{i32 8, !"PIC Level", i32 2}
!9 = !{i32 7, !"uwtable", i32 1}
!10 = !{i32 7, !"frame-pointer", i32 1}
!11 = !{i32 1, !"Swift Version", i32 7}
!12 = !{!"standard-library", i1 false}
!13 = !{!"-lswiftFoundation"}
!14 = !{!"-framework", !"Foundation"}
!15 = !{!"-lswiftCore"}
!16 = !{!"-lswift_DarwinFoundation3"}
!17 = !{!"-lswift_DarwinFoundation1"}
!18 = !{!"-lswift_DarwinFoundation2"}
!19 = !{!"-lswift_StringProcessing"}
!20 = !{!"-lswift_Concurrency"}
!21 = !{!"-lswiftSystem"}
!22 = !{!"-lswiftDarwin"}
!23 = !{!"-lswift_Builtin_float"}
!24 = !{!"-lswiftObservation"}
!25 = !{!"-lswiftObjectiveC"}
!26 = !{!"-lswiftCoreFoundation"}
!27 = !{!"-framework", !"CoreFoundation"}
!28 = !{!"-lswiftDispatch"}
!29 = !{!"-framework", !"Combine"}
!30 = !{!"-framework", !"CoreServices"}
!31 = !{!"-framework", !"Security"}
!32 = !{!"-lswiftXPC"}
!33 = !{!"-framework", !"CFNetwork"}
!34 = !{!"-framework", !"DiskArbitration"}
!35 = !{!"-lswiftIOKit"}
!36 = !{!"-framework", !"IOKit"}
!37 = !{!"-lobjc"}
!38 = !{}
!39 = !{!"branch_weights", !"expected", i32 1, i32 2000}
!40 = !{i64 0, i64 9223372036854775807}
!41 = !{!"branch_weights", !"expected", i32 2144622663, i32 2860985}
!42 = !{!"branch_weights", !"expected", i32 2000, i32 1}
!43 = !{!"branch_weights", i32 1, i32 1999}
