# Changelog

## 0.3.0 (2026-06-10)

### Changed
- Removed the unused `ConnectionPool` GenServer and the `pool_size` config
  option. Connection pooling is handled by Req/Finch.
- Narrowed token-generation `rescue` to expected error types so programmer errors propagate.

## 0.2.0 (2026-06-09)

- Coordinated version bump across all packages; added missing documentation

## 0.1.0 (2025-04-13)

- Initial release
- APNs client with JWT auth and HTTP/2 support
- standard, background, and VoIP push helpers
