# Pomerium Core, official image (debug variant: same binary, plus a shell for the start script).
# Pinned by version and digest. Update both together, and add a CHANGELOG.md entry.
FROM pomerium/pomerium:debug-v0.34.1@sha256:ac62ca9f31622f649400eae1e89d596e2561a19c7a4c0ad43903daf52ea63e0f

COPY start.sh /usr/local/bin/railway-start.sh

ENV PORT=8080
EXPOSE 8080

ENTRYPOINT ["/bin/bash", "/usr/local/bin/railway-start.sh"]
