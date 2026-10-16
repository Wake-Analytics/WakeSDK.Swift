#if DEBUG || WAKE_IDENTITY_TOOLS
extension Wake {

    // Identity tools for manual testing, compiled in only under DEBUG or the
    // WAKE_IDENTITY_TOOLS flag.

    /// The current subject id, exactly as it lands in ingest.
    public static var debugCurrentInstallID: String? {
        Core.shared.debugCurrentInstallID
    }

    /// Drops the local subject, so the next `start` mints a new install id.
    public static func debugResetIdentity() {
        Core.shared.debugResetIdentity()
    }

    /// Pins the subject to `id`, so the next `start` resumes it with no `$first_launch`.
    public static func debugSetInstallID(_ id: String) {
        Core.shared.debugSetInstallID(id)
    }
}
#endif // DEBUG || WAKE_IDENTITY_TOOLS
