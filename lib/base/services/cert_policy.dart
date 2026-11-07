/// Whether HTTPS connections accept any certificate.
///
/// A server on the LAN - a NAS, typically - is often reachable only over a
/// self-signed certificate, and then every request fails the handshake until
/// the user opts out of validation for that server. Applied in
/// [initSystemProxy]'s HttpClient overrides, so it covers API requests, cover
/// art and the local relay alike.
bool ignoreServerCert = false;
