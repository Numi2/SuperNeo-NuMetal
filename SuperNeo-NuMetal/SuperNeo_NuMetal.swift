/// SuperNeo-NuMetal implements the core algebra and protocol surface for the
/// SuperNeo folding construction over the Goldilocks field.
public enum SuperNeoNuMetal {
    /// The semantic package version for this Swift module.
    public static let packageVersion = "0.1.0"

    /// The default parameter profile exposed by the package.
    public static let defaultParameters = SuperNeoParameters.goldilocks

    /// The binary proof envelope version currently emitted by serializers.
    public static let proofEnvelopeVersion = ProofEnvelopeHeader.version
}
