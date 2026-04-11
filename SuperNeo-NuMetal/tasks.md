prover-only math on field/ring oracles, public verifier on parsed proof objects plus commitments, and GPU kernels only for prover hot paths.

The paper you pasted is a HyperNova-style lattice fold: one small-extension-field sum-check, Ajtai commitments, and a folding pipeline ΠCCS -> ΠRLC -> ΠDEC. That is the right implementation boundary to preserve in Swift.  ￼

1. (x) Real sum-check polynomial protocol

Do not materialize the full multivariate polynomial Q(X).

Implement sum-check as an oracle protocol over a prover-backed evaluator. The prover owns witness-backed access to the helper pieces:
	•	F(X) for CCS vanishing checks
	•	NC(X) for norm checks
	•	Eval(X) for prior CE checks
	•	Q(X) = eq(X, α) * (F(X) + γ^K * NC(X)) + γ^(2K+k) * Eval(X)

In code, that means:

protocol SumcheckOracle {
    associatedtype FE: FieldElement

    var numVars: Int { get }
    var maxDegreePerRound: Int { get }

    /// Returns coefficients of g_i(t) for the current prefix r_1..r_{i-1}.
    /// coeffs[j] is coefficient of t^j.
    mutating func roundPolynomial(prefix: [FE]) throws -> [FE]

    /// Final direct evaluation Q(r_1,...,r_l).
    mutating func finalEvaluation(point: [FE]) throws -> FE
}

struct SumcheckRound<FE: FieldElement>: Codable {
    let coeffs: [FE]
}

struct SumcheckProof<FE: FieldElement>: Codable {
    let claimedSum: FE
    let rounds: [SumcheckRound<FE>]
    let finalPoint: [FE]
    let finalValue: FE
}

The verifier flow is standard and public:

func verifySumcheck<FE: FieldElement>(
    proof: SumcheckProof<FE>,
    transcript: inout Transcript,
    expectedDegree: Int,
    finalCheck: (Array<FE>, FE) throws -> Bool
) throws -> Bool {
    var claim = proof.claimedSum
    var prefix: [FE] = []

    for round in proof.rounds {
        guard !round.coeffs.isEmpty, round.coeffs.count <= expectedDegree + 1 else { return false }

        let g0 = evalPoly(round.coeffs, at: .zero)
        let g1 = evalPoly(round.coeffs, at: .one)
        guard g0 + g1 == claim else { return false }

        let ri: FE = transcript.challengeScalar()
        prefix.append(ri)
        claim = evalPoly(round.coeffs, at: ri)
    }

    guard prefix == proof.finalPoint else { return false }
    guard claim == proof.finalValue else { return false }
    return try finalCheck(proof.finalPoint, proof.finalValue)
}

For the prover, each roundPolynomial(prefix:) must do the actual partial hypercube sum over the remaining Boolean variables. For performance, never recurse naively over full witness vectors. Precompute the multilinear basis weights for the fixed verifier challenges you already know in that round, and stream through rows/tiles. That is where the GPU belongs.

For ΠCCS, the final check is not “open the witness”. It is “recompose the verifier-side scalar identity from the proof’s final evaluation payload”:

v \stackrel{?}= eq(r',\alpha)\cdot(F + \gamma^K N) + \gamma^{2K+k}E

with F, N, and E derived from the proof-carried final evaluations, not from witness data.

Implementation status: complete. The sum-check verifier checks every round identity, final point, final value, and public final callback. Prover oracles stream actual partial hypercube sums from evaluator/oracle state, prior-accumulator claimed sums are scaled by the same γ^(2K+k) factor used in Q, and invalid oracle dimensions or degree bounds now surface as thrown errors instead of runtime preconditions.

2. (x) Public verifier flow without witnesses

The verifier must never depend on z, w, or any witness-derived table.

Your public verifier input should be only:
	•	profile / shape digest
	•	statement digest
	•	commitments c_i
	•	public inputs x_i
	•	prior evaluation point r
	•	prior claimed evaluations y_i,j
	•	proof bytes

The verifier then does this in order:
	1.	Parse and structurally validate the proof.
	2.	Recompute Fiat-Shamir transcript challenges from public data only.
	3.	Verify ΠCCS sum-check round identities.
	4.	Verify the final Q(r') recomposition from the proof’s final evaluation payload.
	5.	Verify ΠRLC linear-combination consistency on commitments and claimed evaluations.
	6.	Verify ΠDEC decomposition consistency if that layer is present in the proof object.
	7.	Verify all profile and shape digests.

The public verifier object should look like this:

struct CCSPublicInstance<FE: FieldElement, RE: RingElement>: Codable {
    let shapeDigest: Digest256
    let statementDigest: Digest256

    let commitments: [Commitment]
    let publicInputs: [[FE]]

    let priorEvalPoint: [FE]?
    let priorClaimedEvals: [[[RE]]]?   // [instance][matrix][ring eval]
}

struct CCSVerifierPayload<FE: FieldElement, RE: RingElement>: Codable {
    let alpha: [FE]              // optional if transcript-derived only; otherwise omit
    let gamma: FE                // same note
    let newEvalPoint: [FE]
    let finalMatrixEvals: [[[RE]]]   // y'_i,j
    let sumcheck: SumcheckProof<FE>
    let rlcChallenges: [RE]?
    let decPayload: DecompositionPayload<FE, RE>?
}

Do not put any witness openings in the proof just to “make verification easier”. That breaks the separation you need.

The only values the verifier should see from the prover at the end of ΠCCS are the fresh evaluation claims y'_i,j, the univariate round polynomials, and whatever compact metadata is needed to recompute the transcript.

Implementation status: complete. `SuperNeoPublicFoldInput` strips witnesses from prior CE claims, `FoldProof` stores witness-free ΠCCS final claims, and `SuperNeoVerifier.verifyFold(publicInput:proof:transcriptSeed:)` derives Fiat-Shamir challenges from public shape/instance/claim bytes only. The transcript uses length-framed absorbs plus SHA-256 counter-mode expansion, samples strong-set ring challenges with rejection sampling instead of modulo reduction, binds explicit instance/prior-claim batch counts, and now absorbs the witness-free ΠCCS final claim batch before deriving ΠRLC challenges, so the random linear-combination challenge binds the prover’s final evaluation message. The sum-check final callback recomposes Q(r') from proof-carried final matrix evaluations, then verifies ΠRLC and ΠDEC using only commitments, public inputs, evaluation claims, and decomposition payloads. Shape power-of-two checks, gamma-power table sizing, and decomposition-scalar construction are reported as thrown verifier/prover errors instead of process preconditions.

3. (x) Complete CCS relation encoding

You need three explicit layers in Swift.

First, the immutable shape:

struct CCSShape<FE: FieldElement>: Codable {
    let version: UInt32
    let fieldModulus: FieldModulusDescriptor
    let extensionDegree: UInt32
    let ringDegree: UInt32

    let m: Int
    let nField: Int
    let nRing: Int
    let nPublicField: Int

    let numMatrices: Int
    let relationDegree: Int

    let matrices: [SparseMatrixCSR<FE>]
    let relationPolynomial: RelationPolynomial
    let hasIdentityFirstMatrix: Bool
}

Second, the public relation instance:

struct CCSInstance<FE: FieldElement>: Codable {
    let commitment: Commitment
    let publicInput: [FE]
}

Third, the private witness:

struct CCSWitness<FE: FieldElement>: Codable {
    let privateWitness: [FE]

    func fullZ(publicInput: [FE]) -> [FE] { publicInput + privateWitness }
}

Then define the CE instance separately:

struct CEInstance<FE: FieldElement, RE: RingElement>: Codable {
    let commitment: Commitment
    let publicInput: [FE]
    let evalPoint: [FE]       // point in K^{log m}
    let matrixEvals: [RE]     // y_j in R_K
}

Two decisions matter here.

First, keep the canonical witness representation in the base field, not the ring. The SuperNeo embedding into ring coefficients is a derived view used for commitment and ring-linear folding, not your source-of-truth storage.

Second, store matrices in sparse field form and derive transformed ring-friendly data as a compiled artifact. Do not make the sparse CCS matrices themselves ring-native.

Implementation status: complete. `CCSShape` carries canonical descriptors, sparse CSR matrices, relation polynomial, relation degree, public-column count, and identity-matrix metadata in its digest, and the validator rejects descriptor/profile drift away from the concrete GoldilocksExt2 / Phi_54 / Ajtai profile implemented here. `CCSInstance`, `CCSWitness`, `CCSEvaluationClaim`, `CEInstance`, and `CCSStatement` are separate public/private/claim layers; `CCSWitness.fullZ(...)` now explicitly derives `[x | w]` without making the ring embedding source-of-truth. Relation evaluation is throwing instead of silently returning zero, public input ring packing is deterministic without force-try, and sparse field matrices remain canonical while transformed ring matrices are derived through `transformedForSuperNeo()`.

For M_1 = I, keep that convention. It gives you direct access to z~(r) through the first matrix slot and simplifies both prover scheduling and verifier recomposition.

4. (x) Proof parsing and deserialization

Make the proof format rigid and non-self-inventing. Use a versioned envelope with canonical lengths.

Recommended envelope:

struct ProofEnvelopeHeader: Codable {
    let magic: UInt32          // e.g. 0x4E_55_4D_51
    let version: UInt16
    let profileID: UInt16
    let shapeDigest: Digest256
    let statementDigest: Digest256
    let transcriptDomain: Digest256
    let bodyLength: UInt32
}

Then body sections in fixed order:
	1.	ΠCCS section
	2.	ΠRLC section
	3.	ΠDEC section
	4.	optional diagnostics section, never hashed into the transcript

For field and ring element encoding:
	•	base-field element: fixed-width little-endian integer, canonical reduced form only
	•	extension-field element: tuple of canonical base-field elements
	•	ring element: fixed-size array of d canonical base-field or extension-field coefficients
	•	sparse matrix references: never inline matrices inside the proof body; only refer by shape digest

Reject on:
	•	trailing bytes
	•	non-canonical field encodings
	•	wrong round counts
	•	wrong coefficient counts for declared degree
	•	profile mismatch
	•	shape mismatch
	•	statement digest mismatch

Use a strict reader:

struct ByteReader {
    private let data: Data
    private var offset: Int = 0

    mutating func read<T: FixedWidthInteger>(_ type: T.Type) throws -> T { /* ... */ }
    mutating func readData(count: Int) throws -> Data { /* ... */ }
    mutating func finish() throws {
        guard offset == data.count else { throw ProofError.trailingBytes }
    }
}

Do not use ad hoc Codable for the wire format. It is fine for internal structs, not for the cryptographic byte format. The wire format needs deterministic field order and canonical encoding.

Implementation status: complete. `ProofEnvelopeHeader` is versioned and fixed-width, `ByteReader` enforces canonical count bounds and trailing-byte rejection, and proof body order is now rigid: PiCCS sum-check/final claims, PiRLC challenges/folded claim, then PiDEC decomposition/output claims. Field, extension, ring, commitment, claim, and decomposition readers use fixed little-endian element widths; parsed proofs reject empty sum-check polynomials, mismatched final-point round counts, empty evaluation payloads, mismatched RLC/PiCCS counts, and decomposition payloads whose commitments/evaluations do not match output claims. Parsed CCS descriptor values now go through throwing validation instead of constructor preconditions.

5. (x) GPU ring matvec / Ajtai commitment scheduling

For this codebase, do not use NTT for the main AG64 / small-degree path.

Use a rotation-add ring matvec path. That matches the pay-per-bit story of the construction and keeps the fast path aligned with small coefficient norms.

The scheduler should be:
	1.	field witness z ∈ F^(d*nR) as canonical input
	2.	SuperNeo coefficient embedding into zRing ∈ R_F^(nR) as a view or packed buffer
	3.	tiled ring matrix-vector multiply c = A * zRing
	4.	optional batched folds z* = Σ ρ_i z_i
	5.	decomposition / split stage only when norm budget requires it

Kernel layout:
	•	one threadgroup handles a tile of output rows κTile
	•	inside a row, accumulate over nRTile
	•	ring multiply is implemented as coefficient-rotation accumulate, not polynomial convolution via NTT
	•	accumulate in widened integer lanes or widened field accumulators, then reduce mod q

Data layout:
	•	store A row-major by ring row, then by input column, then by coefficient
	•	also keep a pre-rotated view if profiling shows it wins
	•	keep zRing packed coefficient-major for coalesced reads

Sketch:

kernel void ajtai_matvec_tiled(
    device const FieldElem *aCoeffs      [[buffer(0)]], // [kappa][nR][d]
    device const FieldElem *zCoeffs      [[buffer(1)]], // [nR][d]
    device FieldElem *outCoeffs          [[buffer(2)]], // [kappa][d]
    constant AjtaiParams& params         [[buffer(3)]],
    uint tgIndex                         [[threadgroup_position_in_grid]],
    uint tid                             [[thread_index_in_threadgroup]]
) {
    // tile row range
    // load z tile
    // for each row and each input ring column:
    //    perform coefficient-rotation multiply-accumulate
    // reduce mod q
    // write output ring coefficients
}

Implementation status: complete. Ajtai commitments accept canonical field witnesses, pack them into SuperNeo ring coefficients, and dispatch explicit batched/tiled Metal matvecs through `AjtaiMatvecSchedule`. The Metal fast path stores messages coefficient-major, uses row/column tile parameters, computes ring multiplication by coefficient rotation/reduction under `Phi_54` instead of NTT, reduces tiled partial rows into commitments, and keeps CPU reference commitment available for non-Metal contexts.

Scheduling in Metal 4 should use one compute encoder for the whole prover batch and explicit pass barriers only where data dependencies exist. Apple’s Metal 4 guidance is to unify compute encoding, use barriers to express dependencies, and parallelize pipeline compilation / loading separately from hot-path encoding. Apple also added command allocators and multithreaded command-buffer encoding for lower CPU overhead.  ￼

For prover throughput, split work across command buffers per fold batch or per matrix family, not per tiny kernel. Tiny-kernel dispatch overhead will dominate.

6. (x) Transformed evaluation kernels

For SuperNeo, the transformed matrix path is mandatory.

Do the linear transform M -> M̄ offline when loading the shape, not during proving. The transform is linear and preserves sparsity structure well enough that you should treat it as compiled shape data, not live work.

Then the prover path for each matrix M_j is:
	1.	compute the transformed row object u_j = M̄_j z
	2.	compute multilinear evaluation at r by inner product with the precomputed basis vector rHat
	3.	emit ring element y_j ∈ R_K

Because multilinear evaluation satisfies:

\widetilde{v}(r) = \langle v, \hat r \rangle

you do not want a generic recursive MLE evaluator on GPU. Precompute rHat on CPU once per verification point, upload it, and use pure weighted reductions on GPU.

Kernel split:
	•	kernel A: sparse transformed matvec, producing row blocks or directly the needed evaluation vector
	•	kernel B: dot with rHat
	•	kernel C: pack coefficient lanes into ring elements in R_K

Sketch:

kernel void transformed_eval_dot(
    device const FieldElem *rows      [[buffer(0)]], // transformed rows or row-products
    device const ExtElem   *rHat      [[buffer(1)]],
    device ExtElem         *evals     [[buffer(2)]],
    constant EvalParams& p            [[buffer(3)]],
    uint gid                          [[thread_position_in_grid]]
) {
    // evals[gid] = <row_g, rHat>
}

If the same r is reused across a whole batch, fuse B and C. If r changes often, keep them separate.

Verifier note: these kernels are prover-only. The verifier should only recombine claimed y_j values and check transcript identities.

Implementation status: complete. `CompiledCCSShape` precomputes transformed ring matrices from sparse CCS matrices as compiled shape data, and prover claim generation reuses those transformed matrices instead of rebuilding them per claim. With a Metal context, PiCCS and PiDEC evaluation claims now use `SuperNeoMetalBackend.transformedEvaluation(matrix:vector:point:)`, which runs transformed matvec followed by the `rHat` weighted dot kernel; CPU evaluation remains the reference fallback. The ring inner-product dual-basis setup is checked and throws on construction failure instead of aborting the process.

7. (x) Archive-backed Metal 4 pipeline loading

This part should be fully availability-gated.

Apple’s Metal 4 compilation API is modular. Apple documents MTL4Archive as a read-only container of compiler-produced pipeline states, makeArchive(url:) for loading an archive from disk, and MTL4PipelineDataSetSerializer for recording descriptors and serializing pipeline scripts for the offline metal-tt pipeline generator. Apple’s WWDC25 guidance is also explicit that archive lookup can miss for several reasons and your app must handle misses by falling back to on-device compilation. Apple also recommends async / parallel compilation, with default QoS for prewarming and streaming.  ￼

That means your loader should be:
	1.	try Metal 4 archive
	2.	if miss, try prebuilt Metal library / dynamic library path
	3.	if miss, compile on device
	4.	optionally record new pipeline data for later harvest

Swift skeleton:

final class PipelineStore {
    private let device: MTLDevice

    init(device: MTLDevice) {
        self.device = device
    }

    func makeComputePipeline(
        descriptor: MTLComputePipelineDescriptor,
        archiveURL: URL?,
        fallbackLibrary: MTLLibrary?
    ) throws -> MTLComputePipelineState {
        if #available(macOS 26, iOS 26, *), let archiveURL {
            if let archive = try? device.makeArchive(url: archiveURL) {
                do {
                    return try archive.makeComputePipelineState(
                        descriptor: descriptor,
                        dynamicLinkingDescriptor: nil
                    )
                } catch {
                    // archive miss or incompatibility; fall through
                }
            }
        }

        if let fn = descriptor.computeFunction {
            return try device.makeComputePipelineState(function: fn)
        }

        throw PipelineError.missingFunction
    }
}

For harvesting, this is implemented in `MetalExecutionContext`:
	•	`MetalPipelineStoreConfiguration(recordPipelineData: true)` attaches an `MTL4PipelineDataSetSerializer` to the Metal 4 compiler.
	•	`writeCapturedPipelineScript(to:)` emits a `metal-tt` pipeline script.
	•	`writeCapturedPipelineArchive(to:)` flushes captured binaries to an archive URL.

Keep two rules:
	•	archive loading is a cache hit optimization, never the only path
	•	pipeline creation stays out of the proving hot path; prewarm at launch or shape-load time

Implementation status: complete. `MetalExecutionContext` uses `MetalPipelineStore` to try availability-gated Metal 4 archive lookup first, then fallback libraries/default library compilation, with optional `MTL4PipelineDataSetSerializer` capture for script/archive harvesting. Pipeline loading is cached and prewarmable, and batched dispatches share one compute encoder with buffer barriers only between dependent commands.

8. (x) Strong sampling set and folded-norm budget enforcement

The SuperNeo paper’s global reduction parameters require a strong sampling set C with expansion factor T and the capacity inequality `(K + k)T(b - 1) < B`, where `B = b^k`, before ΠRLC can safely fold `K + k` evaluation claims and ΠDEC can split the folded claim back into norm-`b` limbs.

Implementation status: complete. `StrongSamplingSetDescriptor` now carries the canonical coefficient set and its expansion factor, so the shape digest binds the exact strong-set norm-growth budget used by Fiat-Shamir ring challenges. The Goldilocks / Phi_54 profile records the theorem-bound expansion factor for `C = {-2,-1,0,1,2}^54`, and prover/verifier input validation rejects fold batches whose `(fresh + prior) * T * (b - 1)` budget is not strictly below the decomposed folded bound `b^decompositionLength`. ΠRLC also now rejects mismatched commitment lengths, public-input lengths, and evaluation points before doing any homomorphic accumulation, and direct Ajtai commitment addition/subtraction is truncation-free for malformed direct API use.

What to do first

Freeze these in this order:
	1.	(x) proof envelope and verifier transcript
	2.	(x) complete CCSShape / CCSInstance / CEInstance encoding
	3.	(x) real sum-check verifier
	4.	(x) prover-side oracle implementation for Q
	5.	(x) transformed evaluation kernels
	6.	(x) Ajtai matvec scheduler
	7.	(x) Metal 4 archive loader
	8.	(x) strong sampling descriptor and fold norm-budget checks


--

record whats finished with a (x)



--

Below is the semantic type set frozen for a faithful Swift implementation of ΠCCS, ΠRLC, and ΠDEC. The production code uses concrete Goldilocks / Phi_54 types, and these boundaries now exist as real Swift APIs instead of task-only notes.

The main correction versus the paper notation is this: in code, keep both the field view and the packed ring view of public inputs explicitly separated. ΠRLC needs the packed ring view for ring-linear folding. The outer CCS relation still lives over field vectors.

import Foundation

// MARK: - Core algebra

public protocol PrimeFieldElement: Equatable, Hashable, Sendable, Codable {
    static var zero: Self { get }
    static var one: Self { get }

    static func + (lhs: Self, rhs: Self) -> Self
    static func - (lhs: Self, rhs: Self) -> Self
    static func * (lhs: Self, rhs: Self) -> Self

    mutating func formAdd(_ rhs: Self)
    mutating func formSub(_ rhs: Self)
    mutating func formMul(_ rhs: Self)
}

public protocol ExtensionFieldElement: Equatable, Hashable, Sendable, Codable {
    associatedtype Base: PrimeFieldElement

    static var zero: Self { get }
    static var one: Self { get }

    static func + (lhs: Self, rhs: Self) -> Self
    static func - (lhs: Self, rhs: Self) -> Self
    static func * (lhs: Self, rhs: Self) -> Self
}

public protocol RingElementProtocol: Equatable, Hashable, Sendable, Codable {
    associatedtype Coeff: PrimeFieldElement

    static var zero: Self { get }

    static func + (lhs: Self, rhs: Self) -> Self
    static func - (lhs: Self, rhs: Self) -> Self
    static func * (lhs: Self, rhs: Self) -> Self

    var coefficients: [Coeff] { get }
}

public protocol ExtensionRingElementProtocol: Equatable, Hashable, Sendable, Codable {
    associatedtype Coeff: ExtensionFieldElement

    static var zero: Self { get }

    static func + (lhs: Self, rhs: Self) -> Self
    static func - (lhs: Self, rhs: Self) -> Self
    static func * (lhs: Self, rhs: Self) -> Self

    var coefficients: [Coeff] { get }
}

/// Commitment values must support ring-linear combinations in ΠRLC.
public protocol RingModuleValue: Equatable, Hashable, Sendable, Codable {
    associatedtype Scalar: RingElementProtocol

    static var zero: Self { get }

    static func + (lhs: Self, rhs: Self) -> Self
    static func * (lhs: Scalar, rhs: Self) -> Self
}

// MARK: - Basic containers

public struct Digest256: Equatable, Hashable, Sendable, Codable {
    public let bytes: [UInt8]
    public init(_ bytes: [UInt8]) {
        precondition(bytes.count == 32)
        self.bytes = bytes
    }
}

public struct FieldVector<FE: PrimeFieldElement>: Equatable, Hashable, Sendable, Codable {
    public let elements: [FE]
    public init(_ elements: [FE]) { self.elements = elements }
}

public struct RingVector<RE: RingElementProtocol>: Equatable, Hashable, Sendable, Codable {
    public let elements: [RE]
    public init(_ elements: [RE]) { self.elements = elements }
}

public struct ExtRingVector<KRE: ExtensionRingElementProtocol>: Equatable, Hashable, Sendable, Codable {
    public let elements: [KRE]
    public init(_ elements: [KRE]) { self.elements = elements }
}

// MARK: - Shape / profile

public struct FieldDescriptor: Equatable, Hashable, Sendable, Codable {
    public let modulusBitWidth: UInt16
    public let extensionDegree: UInt16
}

public struct CyclotomicDescriptor: Equatable, Hashable, Sendable, Codable {
    public let degree: UInt16
    public let coefficientsLittleEndian: [Int64]
}

public struct AjtaiDescriptor: Equatable, Hashable, Sendable, Codable {
    public let kappa: UInt32
    public let ringLength: UInt32
    public let ringDegree: UInt16
    public let normBoundSmall: UInt32   // b
    public let normBoundFolded: UInt32  // B = b^k
    public let decomposeBase: UInt32    // b
    public let decomposeLimbs: UInt16   // k
}

public struct StrongSamplingSetDescriptor: Equatable, Hashable, Sendable, Codable {
    public let coefficientSet: [Int16]
    public let expansionFactor: UInt32
}

public struct RelationMonomial<FE: PrimeFieldElement>: Equatable, Hashable, Sendable, Codable {
    public let coefficient: FE
    public let exponents: [UInt16]   // one exponent per CCS matrix slot
}

public struct RelationPolynomial<FE: PrimeFieldElement>: Equatable, Hashable, Sendable, Codable {
    public let variableCount: UInt16
    public let monomials: [RelationMonomial<FE>]
}

public struct SparseMatrixCSR<FE: PrimeFieldElement>: Equatable, Hashable, Sendable, Codable {
    public let rowCount: Int
    public let colCount: Int
    public let rowOffsets: [Int]
    public let columnIndices: [Int]
    public let values: [FE]
}

public struct CCSShape<FE: PrimeFieldElement>: Equatable, Hashable, Sendable, Codable {
    public let version: UInt32
    public let shapeDigest: Digest256

    public let field: FieldDescriptor
    public let cyclotomic: CyclotomicDescriptor
    public let ajtai: AjtaiDescriptor
    public let challenges: StrongSamplingSetDescriptor

    public let m: Int
    public let nField: Int
    public let nRing: Int
    public let nPublicField: Int
    public let nPublicRing: Int

    public let numMatrices: Int
    public let relationDegree: Int

    public let matrices: [SparseMatrixCSR<FE>]
    public let relationPolynomial: RelationPolynomial<FE>

    /// Freeze M1 = I to match the paper’s simplification.
    public let firstMatrixIsIdentity: Bool
}

/// Prover-only compiled artifacts.
/// These are not serialized into proofs.
public struct CCSCompiledArtifacts<
    FE: PrimeFieldElement,
    RE: RingElementProtocol
>: Sendable {
    public let shapeDigest: Digest256

    /// Sparse base-field matrices M_j.
    public let matrices: [SparseMatrixCSR<FE>]

    /// Precomputed transformed matrices \bar{M_j} for SuperNeo.
    /// Store in the format that matches your GPU kernels.
    public let transformedMatrices: [SparseMatrixCSR<FE>]

    /// Ajtai matrix A in GPU-friendly packed form.
    public let ajtaiPackedBytes: Data

    public init(
        shapeDigest: Digest256,
        matrices: [SparseMatrixCSR<FE>],
        transformedMatrices: [SparseMatrixCSR<FE>],
        ajtaiPackedBytes: Data
    ) {
        self.shapeDigest = shapeDigest
        self.matrices = matrices
        self.transformedMatrices = transformedMatrices
        self.ajtaiPackedBytes = ajtaiPackedBytes
    }
}

// MARK: - Public input encoding

/// This resolves the paper’s field/ring notation mismatch cleanly.
/// - field: outer CCS API and digest binding
/// - packed: recursive folding algebra for ΠRLC / ΠDEC
public struct PublicInputEncoding<
    FE: PrimeFieldElement,
    RE: RingElementProtocol
>: Equatable, Hashable, Sendable, Codable {
    public let field: FieldVector<FE>
    public let packed: RingVector<RE>

    public init(field: FieldVector<FE>, packed: RingVector<RE>) {
        self.field = field
        self.packed = packed
    }
}

// MARK: - CCS and CE claims

public struct CCSPublicClaim<
    FE: PrimeFieldElement,
    RE: RingElementProtocol,
    C: RingModuleValue
>: Equatable, Hashable, Sendable, Codable where C.Scalar == RE {
    public let commitment: C
    public let publicInput: PublicInputEncoding<FE, RE>

    public init(
        commitment: C,
        publicInput: PublicInputEncoding<FE, RE>
    ) {
        self.commitment = commitment
        self.publicInput = publicInput
    }
}

public struct CCSPrivateWitness<FE: PrimeFieldElement>: Equatable, Hashable, Sendable, Codable {
    public let privateWitnessField: FieldVector<FE>

    public init(privateWitnessField: FieldVector<FE>) {
        self.privateWitnessField = privateWitnessField
    }
}

public struct CCSFullClaim<
    FE: PrimeFieldElement,
    RE: RingElementProtocol,
    C: RingModuleValue
>: Sendable, Codable where C.Scalar == RE {
    public let publicClaim: CCSPublicClaim<FE, RE, C>
    public let privateWitness: CCSPrivateWitness<FE>

    public init(
        publicClaim: CCSPublicClaim<FE, RE, C>,
        privateWitness: CCSPrivateWitness<FE>
    ) {
        self.publicClaim = publicClaim
        self.privateWitness = privateWitness
    }
}

public struct CEPublicClaim<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Equatable, Hashable, Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let commitment: C
    public let publicInput: PublicInputEncoding<FE, RE>
    public let evalPoint: [KFE]      // r in K^{log m}
    public let matrixEvals: [KRE]    // y_j in R_K, count = t

    public init(
        commitment: C,
        publicInput: PublicInputEncoding<FE, RE>,
        evalPoint: [KFE],
        matrixEvals: [KRE]
    ) {
        self.commitment = commitment
        self.publicInput = publicInput
        self.evalPoint = evalPoint
        self.matrixEvals = matrixEvals
    }
}

/// Prover-only witness view for CE.
/// Keep the canonical field witness and the packed ring witness together.
public struct CEPrivateWitness<
    FE: PrimeFieldElement,
    RE: RingElementProtocol
>: Sendable, Codable {
    public let zField: FieldVector<FE>
    public let zPacked: RingVector<RE>

    public init(zField: FieldVector<FE>, zPacked: RingVector<RE>) {
        self.zField = zField
        self.zPacked = zPacked
    }
}

public struct CEFullClaim<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let publicClaim: CEPublicClaim<FE, KFE, RE, KRE, C>
    public let privateWitness: CEPrivateWitness<FE, RE>

    public init(
        publicClaim: CEPublicClaim<FE, KFE, RE, KRE, C>,
        privateWitness: CEPrivateWitness<FE, RE>
    ) {
        self.publicClaim = publicClaim
        self.privateWitness = privateWitness
    }
}

// MARK: - Sum-check

public struct SumcheckRound<KFE: ExtensionFieldElement>: Equatable, Hashable, Sendable, Codable {
    /// coeffs[j] is the coefficient of t^j.
    public let coeffs: [KFE]
    public init(coeffs: [KFE]) { self.coeffs = coeffs }
}

public struct SumcheckProof<KFE: ExtensionFieldElement>: Equatable, Hashable, Sendable, Codable {
    public let claimedSum: KFE
    public let rounds: [SumcheckRound<KFE>]
    public let finalPoint: [KFE]     // r'
    public let finalValue: KFE       // Q(r')

    public init(
        claimedSum: KFE,
        rounds: [SumcheckRound<KFE>],
        finalPoint: [KFE],
        finalValue: KFE
    ) {
        self.claimedSum = claimedSum
        self.rounds = rounds
        self.finalPoint = finalPoint
        self.finalValue = finalValue
    }
}

// MARK: - ΠCCS

public struct PiCCSVerifierInput<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let shape: CCSShape<FE>
    public let newCCSClaims: [CCSPublicClaim<FE, RE, C>]      // K
    public let priorAccumulator: [CEPublicClaim<FE, KFE, RE, KRE, C>] // k

    public init(
        shape: CCSShape<FE>,
        newCCSClaims: [CCSPublicClaim<FE, RE, C>],
        priorAccumulator: [CEPublicClaim<FE, KFE, RE, KRE, C>]
    ) {
        self.shape = shape
        self.newCCSClaims = newCCSClaims
        self.priorAccumulator = priorAccumulator
    }
}

public struct PiCCSProverInput<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let shape: CCSShape<FE>
    public let compiled: CCSCompiledArtifacts<FE, RE>
    public let newCCSClaims: [CCSFullClaim<FE, RE, C>]        // K
    public let priorAccumulator: [CEFullClaim<FE, KFE, RE, KRE, C>] // k

    public init(
        shape: CCSShape<FE>,
        compiled: CCSCompiledArtifacts<FE, RE>,
        newCCSClaims: [CCSFullClaim<FE, RE, C>],
        priorAccumulator: [CEFullClaim<FE, KFE, RE, KRE, C>]
    ) {
        self.shape = shape
        self.compiled = compiled
        self.newCCSClaims = newCCSClaims
        self.priorAccumulator = priorAccumulator
    }
}

/// Witness-free proof section for ΠCCS.
/// This section carries the sum-check transcript and witness-free output CE claims.
public struct PiCCSSection<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Equatable, Hashable, Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let sumcheck: SumcheckProof<KFE>
    public let finalClaims: [CEPublicClaim<FE, KFE, RE, KRE, C>] // K + k

    public init(
        sumcheck: SumcheckProof<KFE>,
        finalClaims: [CEPublicClaim<FE, KFE, RE, KRE, C>]
    ) {
        self.sumcheck = sumcheck
        self.finalClaims = finalClaims
    }
}

public struct PiCCSOutput<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let freshClaims: [CEPublicClaim<FE, KFE, RE, KRE, C>] // K + k

    public init(freshClaims: [CEPublicClaim<FE, KFE, RE, KRE, C>]) {
        self.freshClaims = freshClaims
    }
}

// MARK: - ΠRLC

public struct PiRLCVerifierInput<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let shape: CCSShape<FE>
    public let batch: [CEPublicClaim<FE, KFE, RE, KRE, C>]  // K + k

    public init(
        shape: CCSShape<FE>,
        batch: [CEPublicClaim<FE, KFE, RE, KRE, C>]
    ) {
        self.shape = shape
        self.batch = batch
    }
}

public struct PiRLCProverInput<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let shape: CCSShape<FE>
    public let batch: [CEFullClaim<FE, KFE, RE, KRE, C>]  // K + k

    public init(
        shape: CCSShape<FE>,
        batch: [CEFullClaim<FE, KFE, RE, KRE, C>]
    ) {
        self.shape = shape
        self.batch = batch
    }
}

/// ΠRLC does not need witness payload in the proof.
/// The only public object worth freezing is the folded CE claim.
/// The verifier derives rho_i from the transcript and recomputes this.
public struct PiRLCSection<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Equatable, Hashable, Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let folded: CEPublicClaim<FE, KFE, RE, KRE, C>

    public init(folded: CEPublicClaim<FE, KFE, RE, KRE, C>) {
        self.folded = folded
    }
}

public struct PiRLCOutput<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let folded: CEPublicClaim<FE, KFE, RE, KRE, C>

    public init(folded: CEPublicClaim<FE, KFE, RE, KRE, C>) {
        self.folded = folded
    }
}

// MARK: - ΠDEC

public struct PiDECVerifierInput<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let shape: CCSShape<FE>
    public let folded: CEPublicClaim<FE, KFE, RE, KRE, C>  // norm B

    public init(
        shape: CCSShape<FE>,
        folded: CEPublicClaim<FE, KFE, RE, KRE, C>
    ) {
        self.shape = shape
        self.folded = folded
    }
}

public struct PiDECProverInput<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let shape: CCSShape<FE>
    public let folded: CEFullClaim<FE, KFE, RE, KRE, C>    // norm B

    public init(
        shape: CCSShape<FE>,
        folded: CEFullClaim<FE, KFE, RE, KRE, C>
    ) {
        self.shape = shape
        self.folded = folded
    }
}

/// Public output only.
/// The prover’s z_i pieces stay private; the verifier checks linear recomposition.
public struct PiDECSection<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Equatable, Hashable, Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let parts: [CEPublicClaim<FE, KFE, RE, KRE, C>]   // count = k

    public init(parts: [CEPublicClaim<FE, KFE, RE, KRE, C>]) {
        self.parts = parts
    }
}

public struct PiDECOutput<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let nextAccumulator: [CEPublicClaim<FE, KFE, RE, KRE, C>] // count = k

    public init(nextAccumulator: [CEPublicClaim<FE, KFE, RE, KRE, C>]) {
        self.nextAccumulator = nextAccumulator
    }
}

// MARK: - Full fold-step proof

public struct FoldProofHeader: Equatable, Hashable, Sendable, Codable {
    public let magic: UInt32
    public let version: UInt16
    public let reserved: UInt16

    public let shapeDigest: Digest256
    public let statementDigest: Digest256
    public let transcriptDomain: Digest256

    public init(
        magic: UInt32,
        version: UInt16,
        reserved: UInt16 = 0,
        shapeDigest: Digest256,
        statementDigest: Digest256,
        transcriptDomain: Digest256
    ) {
        self.magic = magic
        self.version = version
        self.reserved = reserved
        self.shapeDigest = shapeDigest
        self.statementDigest = statementDigest
        self.transcriptDomain = transcriptDomain
    }
}

public struct FoldStepProof<
    FE: PrimeFieldElement,
    KFE: ExtensionFieldElement,
    RE: RingElementProtocol,
    KRE: ExtensionRingElementProtocol,
    C: RingModuleValue
>: Sendable, Codable
where KFE.Base == FE, C.Scalar == RE {
    public let header: FoldProofHeader
    public let piCCS: PiCCSSection<FE, KFE, RE, KRE, C>
    public let piRLC: PiRLCSection<FE, KFE, RE, KRE, C>
    public let piDEC: PiDECSection<FE, KFE, RE, KRE, C>

    public init(
        header: FoldProofHeader,
        piCCS: PiCCSSection<FE, KFE, RE, KRE, C>,
        piRLC: PiRLCSection<FE, KFE, RE, KRE, C>,
        piDEC: PiDECSection<FE, KFE, RE, KRE, C>
    ) {
        self.header = header
        self.piCCS = piCCS
        self.piRLC = piRLC
        self.piDEC = piDEC
    }
}

// MARK: - Transcript and engine interfaces

public protocol Transcript: Sendable {
    associatedtype FE: PrimeFieldElement
    associatedtype KFE: ExtensionFieldElement where KFE.Base == FE
    associatedtype RE: RingElementProtocol where RE.Coeff == FE

    mutating func absorb(bytes: [UInt8])
    mutating func absorbDigest(_ digest: Digest256)
    mutating func challengeBaseField() -> FE
    mutating func challengeExtensionField() -> KFE
    mutating func challengeRingElement() -> RE
}

public protocol PiCCSEngine {
    associatedtype FE: PrimeFieldElement
    associatedtype KFE: ExtensionFieldElement where KFE.Base == FE
    associatedtype RE: RingElementProtocol where RE.Coeff == FE
    associatedtype KRE: ExtensionRingElementProtocol
    associatedtype C: RingModuleValue where C.Scalar == RE
    associatedtype T: Transcript where T.FE == FE, T.KFE == KFE, T.RE == RE

    func prove(
        input: PiCCSProverInput<FE, KFE, RE, KRE, C>,
        transcript: inout T
    ) throws -> PiCCSSection<FE, KFE, RE, KRE, C>

    func verify(
        input: PiCCSVerifierInput<FE, KFE, RE, KRE, C>,
        proof: PiCCSSection<FE, KFE, RE, KRE, C>,
        transcript: inout T
    ) throws -> PiCCSOutput<FE, KFE, RE, KRE, C>
}

public protocol PiRLCEngine {
    associatedtype FE: PrimeFieldElement
    associatedtype KFE: ExtensionFieldElement where KFE.Base == FE
    associatedtype RE: RingElementProtocol where RE.Coeff == FE
    associatedtype KRE: ExtensionRingElementProtocol
    associatedtype C: RingModuleValue where C.Scalar == RE
    associatedtype T: Transcript where T.FE == FE, T.KFE == KFE, T.RE == RE

    func prove(
        input: PiRLCProverInput<FE, KFE, RE, KRE, C>,
        transcript: inout T
    ) throws -> PiRLCSection<FE, KFE, RE, KRE, C>

    func verify(
        input: PiRLCVerifierInput<FE, KFE, RE, KRE, C>,
        proof: PiRLCSection<FE, KFE, RE, KRE, C>,
        transcript: inout T
    ) throws -> PiRLCOutput<FE, KFE, RE, KRE, C>
}

public protocol PiDECEngine {
    associatedtype FE: PrimeFieldElement
    associatedtype KFE: ExtensionFieldElement where KFE.Base == FE
    associatedtype RE: RingElementProtocol where RE.Coeff == FE
    associatedtype KRE: ExtensionRingElementProtocol
    associatedtype C: RingModuleValue where C.Scalar == RE
    associatedtype T: Transcript where T.FE == FE, T.KFE == KFE, T.RE == RE

    func prove(
        input: PiDECProverInput<FE, KFE, RE, KRE, C>,
        transcript: inout T
    ) throws -> PiDECSection<FE, KFE, RE, KRE, C>

    func verify(
        input: PiDECVerifierInput<FE, KFE, RE, KRE, C>,
        proof: PiDECSection<FE, KFE, RE, KRE, C>,
        transcript: inout T
    ) throws -> PiDECOutput<FE, KFE, RE, KRE, C>
}

The important invariants to enforce are these.

ΠCCS
	•	newCCSClaims.count == K
	•	priorAccumulator.count == k
	•	proof.finalClaims.count == K + k
	•	every finalClaims[i].matrixEvals.count == shape.numMatrices
	•	proof.sumcheck.finalPoint.count == log2(shape.m)

ΠRLC
	•	input.batch.count == K + k
	•	all input CE claims have the same evalPoint
	•	proof.folded.evalPoint == input.batch[0].evalPoint
	•	verifier derives ρ_i from transcript, recomputes folded commitment, folded packed public input, and folded matrix evaluations, then compares to proof.folded

	ΠDEC
		•	proof.parts.count == shape.ajtai.decomposeLimbs
		•	every part has the same evalPoint as the folded claim
		•	verifier checks
		•	c == Σ b^(i-1) c_i
		•	x_packed == Σ b^(i-1) x_i_packed
		•	y_j == Σ b^(i-1) y_i,j
		•	(x) implementation computes each limb’s Ajtai commitment and transformed matrix evaluations y_i,j, then verifies the public weighted recomposition equations above

Three implementation decisions should stay fixed.

First, the prover-only witness type is CEPrivateWitness, not anything carried in the public proof. The verifier never sees zField or zPacked.

Second, ΠRLC is effectively a transcript-driven deterministic reduction plus a public output claim. The proof section is just the claimed folded output. No witness payload belongs there.

Third, the wire format should not use generic Codable directly. These structs are the semantic model. The actual byte parser should be a fixed canonical serializer with exact field widths and no optional or map-like encodings.

(x) Verifier skeleton frozen. `PiCCSSection`, `PiRLCSection`, `PiDECSection`, and `FoldStepProof` are now concrete witness-free Swift proof-section types. `FoldProof` exposes those sections directly, the canonical parser reads the body in section order, and `SuperNeoVerifier.verifyFold(publicInput:proof:transcriptSeed:)` consumes the same public section data to enforce the ΠCCS final-Q identity, ΠRLC transcript-derived recomposition, and ΠDEC weighted commitment / packed-public-input / evaluation recomposition equations.

----

Concrete parameters
This section provides three efficient parameterizations over ≤64-bit fields. Addi-
tionally, Appendix D.7 and Appendix D.8 provide the corresponding sage scripts
that we used to determine valid parameterizations. In Definition 14, we require
the commitment scheme to be (d,m,2B,C)-relaxed binding (Definition 4). Thus,
we need the commitment scheme to be (d,m,4TB)-binding (Definition 4). Finally,
Ajtai’s commitment scheme is (d,m,4TB)-binding if MSIS∞,κ,q
m,8TB is hard. We
estimate the hardness of Module-SIS using the lattice estimator library provided
by [4] using our script (Appendix D.8).
B.1 Almost Goldilocks: (264
− 232 + 1)− 32
We provide a new field, which we refer to as Almost Goldilocks. This field’s order
is q = (264
−232 + 1)−32, which is close to the order of the Goldilocks field
264
−232 + 1. Because of this, the field admits an efficient implementation with a
small change to the Solinas prime reduction algorithm (which is typically used
for the Goldilocks field).
η= 128, Φ = X64 + 1, d= 64, RF := F [X]/(Φ), κ= 15, nF = 233
, b= 2, k= 13,
K ∈[50], B = 213. Define Cto be the set polynomials in RF whose coefficients
belong to [−1,0,1,2]. By Theorem 9, T = 128. By Theorem 8, binv ≈4. K= Fq2 .
|C|= 2128
, |K|≈2128
, MSIS∞,κ,q
m,8TB ≈129 bits of security.
B.2 Goldilocks: (264
− 232 + 1)
This is a popular choice of field for SNARKs as the field admits an efficient
implementation: field operations can be implemented with essentially only bit-
shifts and the field has high 2-adicity (232 |(p−1)), which is useful for compressing
Neo’s IVC proofs with SNARKs.
η = 81, Φ = X54 + X27 + 1, d= 54, RF := F [X]/(Φ), κ= 18, nF = 230
, b= 2,
k = 14, K ∈[61], B = 214. Define Cto be the set polynomials in RF whose
coefficients belong to [−2,−1,0,1,2]. By Theorem 9, T = 216. By Theorem 8,
binv ≈2.5·109
. K= Fq2 .
|C|≈2125
, |K|≈2128
, MSIS∞,κ,q
m,8TB ≈129 bits of security.
38
Remark 4 (Incompatibility with Latticefold [14]). In LatticeFold [14], the construc-
tions and analysis are limited to power-of-two cyclotomic polynomials, namely
of the form Xd + 1 with d being a power-of-two. Since the Goldilocks field has
high 2-adicity, the cyclotomic polynomial completely factors into linear terms.
This means that the ring RF is isomorphic to F d
q (the NTT representation). The
security of LatticeFold’s construction depends on the size of the field in the NTT
representation [14, Sec 3.3], which here is only 64 bits.
B.3 Mersenne 61: 261
− 1
This field admits an incredibly efficient implementation as it is only one off from a
power-of-two. Specifically, modular arithmetic over this field can be implemented
with simple bit-shifts with an algorithm more efficient than Goldilocks.
η = 81, Φ = X54 + X27 + 1, d= 54, RF := F [X]/(Φ), κ= 18, nF = 228
, b= 2,
k = 14, K ∈[61], B = 214. Define Cto be the set polynomials in RF whose
coefficients belong to [−2,−1,0,1,2]. By Theorem 9, T = 216. By Theorem 8,
binv ≈383. K= Fq2 .
|C|≈2125
, |K|≈2122
, MSIS∞,κ,q
m,8TB ≈129 bits of security.
Remark 5 (Incompatibility with Latticefold [14]). As stated earlier, LatticeFold’s
constructions and analysis are limited to power-of-two cyclotomic polynomials,
namely of the form Xd+1 for dbeing a power-of-two. For Mersenne 61, there is no
choice of power-of-two cyclotomic polynomials, which satisfies the requirements
of Theorem 8. Hence, it cannot be determined whether a choice of parameters
with Φ = Xd + 1 leads to a secure construction.